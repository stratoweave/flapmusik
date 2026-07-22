# XRd Bridge Lab

A minimal [Containerlab](https://containerlab.dev/) lab that starts a **single
Cisco IOS XRd** router and **bridges its data-plane port onto the host's
physical `enx6c6e0741e7a9` interface** connected to NCS5502.

The XRd router's `GigabitEthernet0/0/0/0` is configured with
**`10.123.0.100/24`** (see `xrd-startup.conf`) and is placed on the same L2
segment as `enx6c6e0741e7a9`, so it can reach anything else living on the
`10.123.0.0/24` network attached to that NIC.

```
                        Linux bridge (br-xrd)
  XRd Gi0/0/0/0  <--- veth --->  [ br-xrd ]  <--- enslaved --->  enx6c6e0741e7a9 (physical)
  10.123.0.100/24                                                 10.123.0.0/24 segment
```

## How the bridging works

Containerlab connects the XRd data-plane veth to a **pre-existing Linux
bridge** named `br-xrd` (the `bridge` kind node in `xrd-bridge.clab.yml`). The
Makefile's `bridge-up` target creates that bridge and enslaves the physical
`enx6c6e0741e7a9` NIC into it before deploying, giving a true L2 bridge between
the router and the physical port. XRd keeps full control of its own veth (MAC,
promiscuous mode), which is why a Linux bridge is used rather than a macvlan.

## Prerequisites

* The physical `enx6c6e0741e7a9` interface present on the host. Override with
  `make start HOST_IFACE=<other-iface>` if the name differs.

> **Note:** `bridge-up` moves `enx6c6e0741e7a9` into the `br-xrd` bridge
> (L2-only). The host must not hold `10.123.0.100/24` (or any other address) on
> that NIC — remove it once with
> `sudo ip addr del 10.123.0.100/24 dev enx6c6e0741e7a9` (and make it persistent
> in your host network config if needed). Don't run this on a NIC the host needs
> for its own connectivity.

## Usage

Start the lab (creates the bridge, enslaves the NIC, deploys XRd):

```sh
make start
```

Open the XRd CLI:

```sh
make cli
```

then verify the interface:

```
show ipv4 interface brief
show running-config interface GigabitEthernet0/0/0/0
ping 10.123.0.1        # ping something on the physical 10.123.0.0/24 segment
```

Follow the boot logs:

```sh
make logs
```

Stop the lab (destroys XRd, releases the NIC, deletes the bridge):

```sh
make stop
```

## Files

| File                  | Purpose                                                        |
| --------------------- | -------------------------------------------------------------- |
| `xrd-bridge.clab.yml` | Containerlab topology: one XRd node + `br-xrd` bridge node.    |
| `xrd-startup.conf`    | XRd startup config; sets `10.123.0.100/24` on Gi0/0/0/0.       |
| `Makefile`            | `start` / `stop` plus host bridge lifecycle (`bridge-up/down`).|

## Login credentials

* Username: `clab`
* Password: `clab@123`
