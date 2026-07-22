TESTENV=flapmusik-xrd-bridge

# Physical host interface the XRd data-plane port is bridged onto.
HOST_IFACE ?= enx6c6e0741e7a9
# Linux bridge that stitches the XRd data-plane veth to $(HOST_IFACE). Must
# match the "bridge" kind node name in xrd-bridge.clab.yml. Keep it <= 15 chars
# (Linux interface name limit).
BRIDGE ?= br-xrd

include ../common/clab.mk

.PHONY: start
start: bridge-up
	$(CLAB_BIN) deploy --topo $(TESTENV:flapmusik-%=%).clab.yml --log-level info --reconfigure

.PHONY: stop
stop:
	-$(CLAB_BIN) destroy --topo $(TESTENV:flapmusik-%=%).clab.yml --log-level info
	$(MAKE) bridge-down

# ---------------------------------------------------------------------------
# Host bridge lifecycle: create $(BRIDGE) and enslave the physical NIC so the
# XRd router shares the L2 segment on $(HOST_IFACE). These commands need root,
# hence sudo. All steps are idempotent.
# ---------------------------------------------------------------------------
.PHONY: bridge-up
bridge-up:
	@if ! ip link show $(BRIDGE) >/dev/null 2>&1; then \
		echo "Creating bridge $(BRIDGE)"; \
		sudo ip link add name $(BRIDGE) type bridge; \
	fi
	@sudo ip link set $(BRIDGE) up
	@if ! ip link show $(HOST_IFACE) >/dev/null 2>&1; then \
		echo "ERROR: host interface $(HOST_IFACE) not found"; exit 1; \
	fi
	@current_master=$$(ip -o link show $(HOST_IFACE) | sed -n 's/.*master \([^ ]*\).*/\1/p'); \
	if [ "$$current_master" != "$(BRIDGE)" ]; then \
		echo "Enslaving $(HOST_IFACE) into $(BRIDGE)"; \
		sudo ip link set $(HOST_IFACE) down; \
		sudo ip link set $(HOST_IFACE) master $(BRIDGE); \
	fi
	@sudo ip link set $(HOST_IFACE) up
	@echo "Bridge $(BRIDGE) is up with member $(HOST_IFACE)"

.PHONY: bridge-down
bridge-down:
	@if ip link show $(HOST_IFACE) >/dev/null 2>&1; then \
		echo "Releasing $(HOST_IFACE) from any bridge"; \
		sudo ip link set $(HOST_IFACE) nomaster 2>/dev/null || true; \
	fi
	@if ip link show $(BRIDGE) >/dev/null 2>&1; then \
		echo "Deleting bridge $(BRIDGE)"; \
		sudo ip link set $(BRIDGE) down 2>/dev/null || true; \
		sudo ip link delete $(BRIDGE) type bridge 2>/dev/null || true; \
	fi

# Drop into the XRd exec CLI.
.PHONY: cli
cli:
	docker exec -it $(TESTENV)-xrd1 /pkg/bin/xr_cli.sh

# Tail the XRd container boot logs.
.PHONY: logs
logs:
	docker logs -f $(TESTENV)-xrd1
