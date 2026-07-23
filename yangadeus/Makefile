# yangadeus — build helpers.
#
# Dependencies resolve from local sibling checkouts (see Build.act): stratoweave
# and midi (midiact) by path, yang pinned to the revision the local stratoweave
# uses. Nothing here needs a network fetch once those are present.

# Release builds are optimized and run faster. Override with `RELEASE=` for a
# debug build (faster to compile).
RELEASE ?= --release

ACTON ?= acton

# The midi bindings (Output actor / pad-LED support) live in the sibling
# ../midiact checkout, overriding the revision pinned in Build.act. Point
# elsewhere with `make MIDI_DEP=--dep\ midi=/abs/path` or clear it (MIDI_DEP=)
# to fall back to the pinned upstream.
MIDI_DEP ?= --dep midi=$(CURDIR)/../midiact

.PHONY: build
build:
	$(ACTON) build $(RELEASE) $(MIDI_DEP) $(TARGET)

.PHONY: debug
debug:
	$(ACTON) build $(MIDI_DEP) $(TARGET)

# Hack on a local acton-yang checkout instead of the pinned revision.
.PHONY: build-ldep
build-ldep:
	$(ACTON) build $(RELEASE) $(MIDI_DEP) --dep yang=$(CURDIR)/../../orc/acton-yang $(TARGET)

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
