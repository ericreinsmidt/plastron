# Everything builds in Docker. `make` produces out/sdcard.img, TortOS on the
# base Pixel 2 system, ready to write to a card at sector 0. `make base`
# produces out/sdcard-base.img, the base system alone.
IMAGE := tortos-px2-builder
VOLUME := tortos-px2-work
# The x86 packing step runs on the same Debian the builder starts from
BASE_IMAGE := debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251
# TortOS and Diatom are built from their own repositories, mounted read-only.
# TortOS's Pixel 2 files are on its gkd-pixel-2 branch, in this worktree;
# Diatom's Pixel 2 port is on its main, so it builds from the main checkout.
TORTOS_SRC ?= $(HOME)/Developer/TortOS/.claude/worktrees/tortos-gkd-pixel2-port-be626c
DIATOM_SRC ?= $(HOME)/Developer/diatom
# The libretro cores TortOS ships, which its mk/fetch-vendor.sh downloads,
# hash-pinned, into the main checkout's vendor/ (ignored by git, so a worktree
# has none of its own)
TORTOS_VENDOR ?= $(HOME)/Developer/TortOS/vendor
# TortOS's ScreenScraper developer pair, compiled into the launcher as on the
# Brick (read by the tortos package). Ignored by git and kept out of the
# source copy the build makes, so it is mounted on its own; without it the
# pair comes out empty and the build carries on.
TORTOS_SS_ENV ?= $(HOME)/Developer/TortOS/.screenscraper.env
SOURCES := -v $(TORTOS_SRC):/tortos:ro -v $(DIATOM_SRC):/diatom:ro -v $(TORTOS_VENDOR):/tortos-vendor:ro \
	$(if $(wildcard $(TORTOS_SS_ENV)),-v $(TORTOS_SS_ENV):/tortos-ss.env:ro)
DOCKER_RUN := docker run --rm -t -v $(CURDIR):/src:ro $(SOURCES) -v $(VOLUME):/work $(IMAGE)

.PHONY: all builder volume image base bootloader shell linux-rebuild copy-out clean-output release

all: image

builder:
	docker build -q -t $(IMAGE) docker

# The volume is created owned by root; the build runs as uid 1000
volume:
	docker volume create $(VOLUME) >/dev/null
	docker run --rm -v $(VOLUME):/work --user root $(IMAGE) chown 1000:1000 /work

image: builder volume
	$(DOCKER_RUN) sh /src/scripts/build.sh
	$(MAKE) copy-out

base: builder volume
	docker run --rm -t -e FLAVOR=base -v $(CURDIR):/src:ro $(SOURCES) -v $(VOLUME):/work $(IMAGE) sh /src/scripts/build.sh
	$(MAKE) copy-out OUTPUT=output-base CARD=sdcard-base.img

# U-Boot, packed into buildroot/board/px2/bootloader/u-boot-px2.bin. Rarely
# needed: the result is committed, and `make` only uses it.
bootloader: builder volume
	$(DOCKER_RUN) sh /src/scripts/build-bootloader.sh
	docker run --rm --platform linux/amd64 -v $(CURDIR):/src -v $(VOLUME):/work \
		$(BASE_IMAGE) sh /src/scripts/pack-bootloader.sh

# Rebuild just the kernel after changing its config, patches or device tree
linux-rebuild: builder volume
	$(DOCKER_RUN) sh /src/scripts/build.sh linux-dirclean all
	$(MAKE) copy-out

# What a release carries, in out/release (scripts/release.sh): the image
# without the developer's SSH key, compressed, and the licenses and sources of
# everything in it. The version is TortOS's, from its Makefile.
VERSION ?= $(shell sed -n 's/^VERSION ?= //p' $(TORTOS_SRC)/Makefile)
release: builder volume
	@[ -n "$(VERSION)" ] || { echo "no VERSION in $(TORTOS_SRC)/Makefile" >&2; exit 1; }
	$(DOCKER_RUN) sh /src/scripts/release.sh $(VERSION)
	rm -rf out/release
	mkdir -p out/release
	docker run --rm -v $(VOLUME):/work -v $(CURDIR)/out:/out --user root $(IMAGE) \
		sh -c 'cp /work/release/* /out/release/ && chown -R $(shell id -u):$(shell id -g) /out/release'
	@ls -l out/release

OUTPUT ?= output
CARD ?= sdcard.img
copy-out:
	mkdir -p out
	docker run --rm -v $(VOLUME):/work -v $(CURDIR)/out:/out --user root $(IMAGE) \
		sh -c 'cp --sparse=never /work/$(OUTPUT)/images/sdcard.img /out/$(CARD) && chown $(shell id -u):$(shell id -g) /out/$(CARD)'
	@ls -l out/$(CARD)

shell: builder volume
	docker run --rm -it -v $(CURDIR):/src:ro $(SOURCES) -v $(VOLUME):/work $(IMAGE) bash

clean-output:
	docker run --rm -v $(VOLUME):/work $(IMAGE) rm -rf /work/output
