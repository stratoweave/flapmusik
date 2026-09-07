TESTENV = flapmusik-ietf-hackathon-frr
TOPOLOGY = ietf-hackathon-frr.clab.yml
NCURL ?= ../../../stratoweave/out/bin/ncurl
FRR = $(TESTENV)-frr-b
# The clear RPC goes to the managed router: FRR ships no NETCONF server and
# its YANG has no BGP clear RPC, so xrd-a is the NETCONF-reachable end.
MANAGED_NETCONF = --host 172.100.61.11 --port 830 --username clab \
	--password clab@123 --insecure
CLEAR_PEER ?= 10.123.1.2
CLEAR_PEER_FRR ?= 10.123.1.1

include ../common/clab.mk

.PHONY: start stop wait copy run state monitor session-clear session-clear-frr cli-a cli-b play listen

start:
	$(CLAB_BIN) deploy --topo $(TOPOLOGY) --reconfigure

stop:
	$(CLAB_BIN) destroy --topo $(TOPOLOGY)

wait:
	timeout --foreground 180 bash -c 'until docker logs $(TESTENV)-xrd-a 2>&1 | grep -q smartlicserver; do sleep 2; done'
	timeout --foreground 180 bash -c 'until docker exec $(FRR) vtysh -c "show bgp ipv4 unicast summary" >/dev/null 2>&1; do sleep 2; done'

cli-a:
	docker exec -it $(TESTENV)-xrd-a /pkg/bin/xr_cli.sh

cli-b:
	docker exec -it $(FRR) vtysh

copy:
	docker cp ../../out/bin/flapmusik $(TESTENV)-sweave:/flapmusik
	docker cp netinfra.xml $(TESTENV)-sweave:/netinfra.xml

run:
	docker exec -it $(TESTENV)-sweave /flapmusik /netinfra.xml \
		--udp-notif-receiver-address 172.100.61.10 \
		--udp-notif-source-interface MgmtEth0/RP0/CPU0/0

state:
	curl -fsS -H 'Accept: application/yang-data+json' \
		http://127.0.0.1:18081/restconf/data | \
		jq '."netinfra:netinfra"."ebgp-peer"'

# Live per-peer session table over flapmusik's northbound NETCONF: an
# on-change YANG-push subscription, schema discovered from the server
# (yang-library + get-schema).
monitor:
	$(NCURL) --host 127.0.0.1 --port 2831 --insecure monitor --on-change \
		--format table --table-path netinfra/ebgp-peer \
		--table-columns router,peer-address,state/session-state

# Flap from the managed router. This is the path yangadeus drives, and the
# recovery is fast because FRR - not XR - re-opens the TCP connection.
# CLEAR_PEER is the external-side address (10.123.N.2), xrd-a's neighbor key.
session-clear:
	printf '%s\n' '<clear-bgp-ip-addr xmlns="http://cisco.com/ns/yang/Cisco-IOS-XR-ipv4-bgp-act"><ip-addr>$(CLEAR_PEER)</ip-addr></clear-bgp-ip-addr>' | \
		$(NCURL) $(MANAGED_NETCONF) rpc /dev/stdin

# The same flap from the external side, over vtysh instead of NETCONF.
# CLEAR_PEER_FRR is the managed-side address (10.123.N.1).
session-clear-frr:
	docker exec $(FRR) vtysh -c "clear bgp ipv4 unicast $(CLEAR_PEER_FRR)"

# ---------------------------------------------------------------------------
# The two players, ../../yangadeus, pinned to this lab's endpoints so nobody
# has to carry the port numbers around. Extra flags pass through in ARGS, e.g.
# `make play ARGS="--base-note 36"`. Build them first: make -C ../../yangadeus
# ---------------------------------------------------------------------------
YANGADEUS ?= ../../yangadeus
# The router yangadeus clears sessions on: xrd-a, because frr-b has no
# NETCONF server and FRR models no BGP clear RPC.
KEYBOARD_HOST ?= 127.0.0.1
KEYBOARD_PORT ?= 1831
# flapmusik's northbound, where kapellmeister reads the session-state feed.
STATE_PORT ?= 2831

play:
	@test -x $(YANGADEUS)/out/bin/yangadeus || \
		{ echo "yangadeus is not built - run: make -C $(YANGADEUS)"; exit 1; }
	$(MAKE) -C $(YANGADEUS) start HOST=$(KEYBOARD_HOST) PORT=$(KEYBOARD_PORT) ARGS="$(ARGS)"

listen:
	@test -x $(YANGADEUS)/out/bin/kapellmeister || \
		{ echo "kapellmeister is not built - run: make -C $(YANGADEUS)"; exit 1; }
	$(MAKE) -C $(YANGADEUS) listen STATE_PORT=$(STATE_PORT) ARGS="$(ARGS)"
