# IOS XR eBGP on-change demo

This lab runs one flapmusik-managed IOS XRd 25.3.1 control-plane router (`xrd-a`)
and one external XRd peer (`xrd-b`). The external router stands in for the
networks outside flapmusik's ownership: its interfaces and BGP neighbors are
supplied entirely by `xrd-b-startup.conf`, and it does not appear in
`netinfra.xml`.

The two routers are joined by a single physical link (`Gi0/0/0/0`), and the
demo multiplexes **25 independent eBGP sessions** onto it with 802.1Q VLAN
subinterfaces — one session per VLAN, sized to the 25 keys of a Novation
Launchkey Mini MK3.

## The setup

The lab is deliberately small: three containers on one management network,
joined by a single link. Everything below is fixed before the demo starts.

**Nodes** — all reachable on the containerlab management network `172.100.60.0/24`:

| Node | mgmt | Role |
| --- | --- | --- |
| `xrd-a` | `172.100.60.11` | Managed router (IOS XRd 25.3.1). flapmusik configures it from `netinfra.xml`. |
| `xrd-b` | `172.100.60.12` | External peer (IOS XRd 25.3.1). Configured by `xrd-b-startup.conf`, and never listed in `netinfra.xml`. |
| `sweave` | `172.100.60.10` | Controller — a Debian container running the `flapmusik` binary. |

**The link** is a single physical link, `xrd-a:Gi0/0/0/0 <-> xrd-b:Gi0/0/0/0`.
The demo slices it into 25 eBGP sessions with 802.1Q subinterfaces: one VLAN `N`
(`1..25`) per session on `Gi0/0/0/0.N`, each addressed
`xrd-a 10.123.N.1/30 <-> xrd-b 10.123.N.2/30`, running eBGP between AS `31337`
(`xrd-a`) and AS `65000` (`xrd-b`).

**Getting in:** both routers speak NETCONF on port `830` (user `clab`, password
`clab@123`). On the host, flapmusik's RESTCONF is at `127.0.0.1:18080` and
`xrd-b`'s NETCONF at `127.0.0.1:1830`. Telemetry is on-change `sync-on-start`,
one subscription per peer over UDP-Notif, with receiver `172.100.60.10` and
source `MgmtEth0/RP0/CPU0/0`.

`/netinfra/peering-interface` names the physical parent (`Gi0/0/0/0`) and lists
25 `subinterface` entries, each with its own `vlan-id` and address
(`10.123.N.1/30` on VLAN `N`). flapmusik's IOS XR transform realizes each as a
dot1q subinterface `Gi0/0/0/0.N`; the physical parent carries no address of its
own.
Each `/netinfra/ebgp-peer` then selects its own `local-address` (`10.123.N.1`)
and peer (`10.123.N.2`). `xrd-a`'s startup configuration deliberately contains
neither the addresses nor BGP, so the demo proves both resources are created
from intended state.

flapmusik monitors `xrd-a`'s BGP operational state through the OpenConfig
network-instance tree with a YANG Push `on-change sync-on-start` subscription
transported over UDP-Notif. XR 25.3.1 accepts the native Cisco BGP tree for
cadence-based telemetry, but only the OpenConfig BGP state path emits
event-driven session changes. The transform requests one on-change
subscription per eBGP peer — 25 in total — and does not configure a periodic
fallback stream. The internal RFS-to-intermediate and intermediate-to-CFS hops
use 100 ms periodic subscriptions because the TTT layer provider does not yet
support on-change subscriptions.

Build flapmusik, then start the lab from the flapmusik repository root:

```sh
acton build --release
cd test/ietf-hackathon-xrd
make start wait copy run
```

In another terminal, inspect the service states and clear a session from the
external router. `xrd-b` attempts to re-establish it, so the useful observation
is the selected peer's on-change transition away from `established` followed by
the transition back:

```sh
make state
make session-clear CLEAR_PEER=10.123.1.1
make session-clear CLEAR_PEER=10.123.25.1
make state
```

`make state` is a one-shot snapshot. For a live view, run the repo-root
[`monitor`](../../monitor) script in its own terminal: it polls the same RESTCONF
endpoint (`127.0.0.1:18080`) every 100 ms and prints one compact row per eBGP
peer — router, peer address, `session-state` — so you can watch a cleared
session drop away from `established` and climb back as you run
`make session-clear` or play `yangadeus`.

```sh
../../monitor        # repo-root script; needs curl + jq
```

The flapmusik process logs the XR UDP-Notif subscription and any malformed,
lost, or out-of-sequence notifications. The subscription uses XR's management
interface as its source so the UDP datagrams are routable to flapmusik.
`session-clear` sends the `Cisco-IOS-XR-ipv4-bgp-act` clear RPC directly to the
external `xrd-b` NETCONF endpoint. `CLEAR_PEER` is the managed-side address
(`10.123.N.1`) used as the neighbor key on `xrd-b`. The RPC does not pass
through flapmusik or StratoWeave's managed-device path.

The `yangadeus` MIDI application plays these sessions from a 25-key keyboard.
It holds a persistent NETCONF session to `xrd-b` (`--host 127.0.0.1 --port
1830`), discovers its eBGP neighbors, sorts them numerically, and lays them
across the keys — lowest key to `10.123.1.1`, highest to `10.123.25.1`. Each
keypress fires a `clear-bgp-ip-addr` RPC for that neighbor while flapmusik
observes the session drop and recover.

The event-driven sensor path is:

```text
openconfig-network-instance:network-instances/network-instance[name='DEFAULT']/protocols/protocol[name='default']/bgp/neighbors/neighbor[neighbor-address='<peer>']/state/session-state
```

The typed selector also carries the protocol `identifier=BGP` key. XR 25.3.1
rejects identityref predicates in configured YANG Push XPath filters, so the
XR dialect adapter omits only that predicate; the string and peer-address keys
remain on the wire and the decoded protocol identity is still checked as BGP.

Stop the process with Ctrl-C, then run `make stop` to remove the lab.
