#!/bin/sh
# The 25 eBGP sessions ride 802.1Q subinterfaces of the single link to xrd-a,
# one VLAN per session. FRR does not create VLAN interfaces, so the kernel
# makes them here and zebra then applies the addresses from frr.conf as each
# one appears.
set -e
for i in $(seq 1 25); do
    ip link add link eth1 name "eth1.$i" type vlan id "$i"
    ip link set dev "eth1.$i" up
done
