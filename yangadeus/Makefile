# Build helpers for the two programs in this project: yangadeus, the keyboard
# that clears eBGP sessions, and kapellmeister, which hears the result.
#
# Dependencies resolve from the pins in Build.act. build-ldep overrides yang
# and stratoweave with local sibling checkouts, and needs no network fetch.

# Release builds are optimized and run faster. Override with `RELEASE=` for a
# debug build (faster to compile).
RELEASE ?= --release

ACTON ?= acton

.PHONY: build
build:
	$(ACTON) build $(RELEASE) $(TARGET)

.PHONY: debug
debug:
	$(ACTON) build $(TARGET)

.PHONY: build-ldep
build-ldep:
	$(ACTON) build $(RELEASE) --dep yang=$(CURDIR)/../../acton-yang --dep stratoweave=$(CURDIR)/../../stratoweave

.PHONY: build-linux-x86_64
build-linux-x86_64:
	$(MAKE) build TARGET="--target x86_64-linux-gnu.2.27"

.PHONY: build-linux-aarch64
build-linux-aarch64:
	$(MAKE) build TARGET="--target aarch64-linux-gnu.2.27"

.PHONY: build-macos-aarch64
build-macos-aarch64:
	$(MAKE) build TARGET="--target aarch64-macos"

.PHONY: clean
clean:
	rm -rf out

# Defaults target the ietf-hackathon-xrd lab's external peer (xrd-b), which
# exposes NETCONF on the host at 127.0.0.1:1830 (see
# ../test/ietf-hackathon-xrd/README.md). Override for a different router, e.g.
# `make start HOST=10.99.0.13 PORT=830`.
HOST ?= 127.0.0.1
PORT ?= 1830
USERNAME ?= clab
PASSWORD ?= clab@123

.PHONY: start
start:
	out/bin/yangadeus --host $(HOST) --port $(PORT) --username $(USERNAME) --password $(PASSWORD) $(ARGS)

# kapellmeister listens to flapmusik's northbound server, not to the router: a
# different host, port and account, so they get their own variables. The
# defaults are the same lab's flapmusik on 127.0.0.1:2830.
STATE_HOST ?= 127.0.0.1
STATE_PORT ?= 2830
STATE_USERNAME ?= admin
STATE_PASSWORD ?= admin

.PHONY: listen
listen:
	out/bin/kapellmeister --host $(STATE_HOST) --port $(STATE_PORT) --username $(STATE_USERNAME) --password $(STATE_PASSWORD) $(ARGS)
