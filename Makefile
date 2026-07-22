
# Release builds are optimized and typically run faster.
# Override with `RELEASE=` for a debug build.
RELEASE ?= --release

.PHONY: build
build:
	acton build $(RELEASE) $(DEP_OVERRIDES) $(TARGET)

.PHONY: build-ldep
build-ldep:
	$(MAKE) build DEP_OVERRIDES="--dep netconf=../netconf --dep stratoweave=../stratoweave --dep yang=../acton-yang --dep actmf=../actmf --dep http_router=../http-router"

.PHONY: build-linux-x86_64
build-linux-x86_64:
	$(MAKE) build TARGET="--target x86_64-linux-gnu.2.27"

.PHONY: build-linux-aarch64
build-linux-aarch64:
	$(MAKE) build TARGET="--target aarch64-linux-gnu.2.27"

.PHONY: build-macos-aarch64
build-macos-aarch64:
	$(MAKE) build TARGET="--target aarch64-macos"

.PHONY: build-linux-aarch64-ldep
build-linux-aarch64-ldep:
	$(MAKE) build DEP_OVERRIDES="--dep netconf=../netconf --dep stratoweave=../stratoweave --dep yang=../acton-yang --dep actmf=../actmf --dep http_router=../http-router" TARGET="--target aarch64-linux-gnu.2.27"

.PHONY: test
test:
	acton test $(DEP_OVERRIDES)

test-ldep:
	$(MAKE) test DEP_OVERRIDES="--dep netconf=../netconf --dep stratoweave=../stratoweave --dep yang=../acton-yang --dep actmf=../actmf --dep http_router=../http-router"

.PHONY: gen
gen:
	cd spec && acton build $(RELEASE) $(DEP_OVERRIDES) && out/bin/flapmusik_gen

.PHONY: gen-ldep
gen-ldep:
	$(MAKE) gen DEP_OVERRIDES="--dep netconf=../../netconf --dep stratoweave=../../stratoweave --dep yang=../../acton-yang --dep actmf=../../actmf --dep http_router=../../http-router"

.PHONY: pkg-upgrade
pkg-upgrade:
	acton pkg upgrade
	cd spec && acton pkg upgrade

