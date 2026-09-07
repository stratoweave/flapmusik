# IOS XR eBGP on-change demo, with an FRR external peer

A variant of [`../ietf-hackathon-xrd/`](../ietf-hackathon-xrd/). The managed
router, the intended state in `netinfra.xml`, the YANG-Push subscriptions and
the UDP-Notif transport are all identical; the only change is the far end of
the link. `xrd-b` is replaced by [FRR](https://frrouting.org/) 10.3.1, and a
cleared session comes back in **under a second instead of about thirty
seconds**.

## Why the peer decides the recovery time

A cleared session is back only when one of the two speakers re-opens the TCP
connection, and IOS XR will not do that for roughly thirty seconds. That timer
is BGP's ConnectRetry, and XR 25.3.1 exposes it nowhere — `timers` under a
neighbor takes a keepalive interval and a hold time, and nothing else, in the
CLI and in `Cisco-IOS-XR-um-router-bgp-cfg` alike. This is the note in
[`src/flapmusik/rfs.act`](../../src/flapmusik/rfs.act).

Nor does the *kind* of disconnect change it. Measured on `xrd-a`, down to up,
in the all-XRd lab:

| disconnect on the external XRd | down → up |
| --- | --- |
| `clear-bgp-ip-addr` (the RPC yangadeus sends) | 29–45 s |
| `clear-bgp-ip-addr-graceful` (`yangadeus --graceful`) | 33 s |
| neighbor `shutdown` → `no shutdown` | 36 s |
| subinterface `shutdown` → `no shutdown` | 32 s |
| `clear tcp pcb` — kill the TCP connection outright | 37 s |
| any of those, plus `session-open-mode active-only` | 47–50 s |

They all land in the same place because they all end the same way: the XR that
received the reset parks the neighbor in `Idle (Neighbor is in closing state)`
for about thirty-five seconds — the router that *issued* the clear is in plain
`Idle` and ready the whole time — and then the handshake takes two seconds.
The `clear tcp pcb` row is the one that settles it: no notification, no
graceful close, no closing state at all, and still 37 s.

FRR has the knob:

```
neighbor 10.123.N.1 timers connect 1
```

It leaves Idle after about a second and re-opens the connection. IOS XR
accepts an inbound connection as soon as it is ready, so the session
re-establishes at FRR's pace, not XR's. Measured in this lab:

| flap | down → up on `xrd-a` | wall clock from the command |
| --- | --- | --- |
| `make session-clear` — RPC to `xrd-a`, the yangadeus path | **0.75 s** | 1.5 s |
| `make session-clear-frr` — `vtysh` on the external peer | **2.5 s** | 2.8 s |

The first column is `xrd-a`'s own `%ROUTING-BGP-5-ADJCHANGE` log, the same
measurement as the table above; the second includes the NETCONF or `vtysh`
round trip.

flapmusik sees the whole transition, not just the ends: one clear produced six
`push-change-update` notifications inside those 0.75 s, so the climb back through
`connect` / `active` / `open-sent` / `open-confirm` arrives as a phrase rather
than either side of a half-minute gap. That is what kapellmeister plays.

This is not "XR is slow and everyone else is fast" — a Juniper cRPD peer took
26.7 s under the same test. FRR is fast here because it is configured to be.

## The clear goes to the managed router

In the all-XRd lab the flap is fired at the external peer, over NETCONF.
`quay.io/frrouting/frr:10.3.1` gives you nowhere to send that RPC:

- no NETCONF server in the image — no `netopeer2-server`, no `sysrepoctl`;
- no northbound plugin built — `/usr/lib/frr/modules/` holds `bgpd_bmp.so`,
  `bgpd_rpki.so`, `dplane_fpm_nl.so`, `pathd_pcep.so` and
  `zebra_cumulus_mlag.so`, and no `sysrepo.so`, `grpc.so` or `confd.so`;
- and no BGP clear RPC to call even if there were. The only `rpc` nodes in
  FRR's shipped YANG are in `frr-ripd`, `frr-ripngd`, `frr-zebra`
  (`clear-rip-route`, `clear-ripng-route`, `clear-evpn-dup-addr`) and
  `frr-test-module`. `frr-bgp*.yang` has none.

So `make session-clear` and yangadeus both send
`Cisco-IOS-XR-ipv4-bgp-act:clear-bgp-ip-addr` to **`xrd-a`** instead, over its
own NETCONF session on `127.0.0.1:1831`. The RPC still does not pass through
flapmusik or StratoWeave's managed-device path, and `xrd-a`'s `session-state`
still leaves `established` the moment it lands — it is now the router that
sends the CEASE rather than the one that receives it. `make session-clear-frr`
keeps the flap on the external side for anyone who wants it, over `vtysh`.

## What differs from the all-XRd lab

|  | `ietf-hackathon-xrd` | this lab |
| --- | --- | --- |
| External peer | `xrd-b`, IOS XRd 25.3.1 | `frr-b`, FRR 10.3.1 |
| Management subnet | `172.100.60.0/24` | `172.100.61.0/24` |
| flapmusik RESTCONF | `127.0.0.1:18080` | `127.0.0.1:18081` |
| flapmusik northbound NETCONF | `127.0.0.1:2830` | `127.0.0.1:2831` |
| NETCONF for the clear RPC | `xrd-b` on `127.0.0.1:1830` | `xrd-a` on `127.0.0.1:1831` |
| Recovery after a clear | 29–50 s | 0.75 s |

The subnets and ports differ so both labs can run at once, which is the point
if you want the comparison side by side.

## The setup

| Node | mgmt | Role |
| --- | --- | --- |
| `xrd-a` | `172.100.61.11` | Managed router (IOS XRd 25.3.1). flapmusik configures it from `netinfra.xml`. |
| `frr-b` | `172.100.61.12` | External peer (FRR 10.3.1). Configured by `frr-b.conf`, never listed in `netinfra.xml`. |
| `sweave` | `172.100.61.10` | Controller — a Debian container running the `flapmusik` binary. |

One link, `xrd-a:Gi0/0/0/0 <-> frr-b:eth1`, sliced into 25 eBGP sessions with
802.1Q subinterfaces: VLAN `N` (`1..25`) carries `10.123.N.1/30` on `xrd-a` and
`10.123.N.2/30` on `frr-b`, between AS `31337` and AS `65000`. FRR does not
create VLAN interfaces, so [`frr-b-vlans.sh`](frr-b-vlans.sh) makes the 25
links from the kernel side at startup and zebra addresses them from
[`frr-b.conf`](frr-b.conf) as each appears.

`xrd-a`'s startup configuration carries neither the addresses nor BGP: both are
created from intended state, exactly as in the all-XRd lab.

## Running it

```sh
acton build --release
cd test/ietf-hackathon-frr
make start wait copy run
```

In another terminal:

```sh
make state                                  # one-shot snapshot
make monitor                                # live on-change table
make session-clear CLEAR_PEER=10.123.1.2    # flap from xrd-a
make session-clear-frr CLEAR_PEER_FRR=10.123.1.1   # flap from frr-b
```

`make cli-a` opens the XR CLI, `make cli-b` opens `vtysh`. `make stop` removes
the lab.

## yangadeus and kapellmeister

Two recipes, so this lab's ports stay out of your head:

```sh
make play      # yangadeus — the keyboard, clearing sessions on xrd-a (:1831)
make listen    # kapellmeister — the sound, on flapmusik's northbound (:2831)
```

Both run the binaries from [`../../yangadeus`](../../yangadeus), so build them
once with `make -C ../../yangadeus`. Extra flags pass through in `ARGS`, e.g.
`make play ARGS="--base-note 36"`, and `KEYBOARD_PORT` / `STATE_PORT` override
the endpoints.

yangadeus discovers the eBGP neighbors from the router's running configuration
at startup, and on `xrd-a` that configuration only exists once flapmusik has
provisioned it — so start flapmusik first. The keys then map to `10.123.1.2`
… `10.123.25.2`, the external addresses as `xrd-a` sees them, low key to low
address, the same order kapellmeister lays out its voices in.
