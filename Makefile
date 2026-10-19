# Everything builds in Docker. `make` produces out/sdcard.img, TortOS on the
# base Pixel 2 system, ready to write to a card at sector 0. `make base`
# produces out/sdcard-base.img, the base system alone.
IMAGE := plastron-builder
VOLUME := plastron-work
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

.PHONY: all builder volume image base brick brick-kernel brick-bootloader brick-probe bootloader shell linux-rebuild copy-out clean-output release

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

# The TrimUI Brick's system (configs/brick_defconfig), in output-brick.
# Imagination's GPU libraries for it are closed and never committed: they
# come from BRICK_GPU, the userspace half of DDK 1.11@5516664 from the Sonic
# Pad SDK (lib64/ and include/), mounted at /brick-gpu.
BRICK_GPU ?= $(HOME)/brick-runtime/gpu-ddk-1.11
# And XRadio's firmware for its XR829 Wi-Fi and Bluetooth chip, closed the same
# way: from BRICK_XR829, mounted at /brick-xr829 (package/xr829-firmware)
BRICK_XR829 ?= $(HOME)/brick-runtime/xr829
# Its kernel and modules come from make brick-kernel, in this volume.
brick: builder volume
	@[ -d "$(BRICK_GPU)/lib64" ] || { echo "no GPU libraries in $(BRICK_GPU): the Brick needs" \
		"Imagination's PowerVR DDK 1.11@5516664 userspace libraries for the GE8300," \
		"which plastron doesn't include (buildroot/package/pvr-ge8300/Config.in" \
		"says which files and where they go)" >&2; exit 1; }
	@[ -f "$(BRICK_XR829)/fw_xr829.bin" ] || { echo "no XR829 firmware in $(BRICK_XR829): the" \
		"Brick's Wi-Fi needs XRadio's firmware files, which plastron doesn't include" \
		"(buildroot/package/xr829-firmware/Config.in says which and where from)" >&2; exit 1; }
	@docker run --rm -v $(VOLUME):/work $(IMAGE) test -f /work/brick-kernel/images/pvrsrvkm.ko || \
		{ echo "no Brick kernel modules yet: make brick-kernel first" >&2; exit 1; }
	docker run --rm -t -e FLAVOR=brick -v $(CURDIR):/src:ro $(SOURCES) \
		-v $(BRICK_GPU):/brick-gpu:ro -v $(BRICK_XR829):/brick-xr829:ro \
		-v $(VOLUME):/work $(IMAGE) sh /src/scripts/build.sh $(BRICK_TARGET)
	$(if $(BRICK_TARGET),,$(MAKE) copy-out OUTPUT=output-brick CARD=brick-sdcard.img)

# The TrimUI Brick's kernel and the modules it loads: Allwinner's Linux 4.9
# with board/brick/linux/patches, built by scripts/build-brick-kernel.sh in
# docker/brick-kernel (the GCC 10 that kernel needs) into the volume's
# brick-kernel/images, where make brick takes the modules from
BRICK_KERNEL_IMAGE := plastron-brick-kernel
brick-kernel: volume
	docker build -q -t $(BRICK_KERNEL_IMAGE) docker/brick-kernel
	docker run --rm -v $(CURDIR):/src:ro -v $(VOLUME):/work $(BRICK_KERNEL_IMAGE) \
		sh /src/scripts/build-brick-kernel.sh

# The TrimUI Brick's boot loader: TF-A's BL31 and U-Boot, built by
# scripts/build-brick-bootloader.sh in docker/brick-boot (the GCC 14 it was
# tested with) into buildroot/board/brick/bootloader/u-boot-sunxi-with-spl.bin,
# which goes 128 KiB into the card. Rarely needed: the result is committed.
BRICK_BOOT_IMAGE := plastron-brick-boot
brick-bootloader: volume
	docker build -q -t $(BRICK_BOOT_IMAGE) docker/brick-boot
	docker run --rm -v $(CURDIR):/src:ro -v $(VOLUME):/work $(BRICK_BOOT_IMAGE) \
		sh /src/scripts/build-brick-bootloader.sh
	mkdir -p buildroot/board/brick/bootloader
	docker run --rm -v $(VOLUME):/work -v $(CURDIR)/buildroot/board/brick/bootloader:/out \
		--user root $(BRICK_BOOT_IMAGE) sh -c 'cp /work/brick-boot/u-boot-sunxi-with-spl.bin /out/ && \
		chown $(shell id -u):$(shell id -g) /out/u-boot-sunxi-with-spl.bin'
	@ls -l buildroot/board/brick/bootloader/u-boot-sunxi-with-spl.bin

# The Brick panel probe (board/brick/probe): a card that shows and saves which
# panel a Brick has, to hand to other Brick owners. Kernel and boot loader only,
# none of Imagination's libraries, so it can be shared. In out/.
brick-probe: builder volume
	docker run --rm -v $(CURDIR):/src:ro -v $(VOLUME):/work $(IMAGE) sh /src/scripts/build-brick-probe.sh
	mkdir -p out
	docker run --rm -v $(VOLUME):/work -v $(CURDIR)/out:/out --user root $(IMAGE) \
		sh -c 'cp /work/brick-probe/brick-panel-probe.img /out/ && chown $(shell id -u):$(shell id -g) /out/brick-panel-probe.img'
	@ls -l out/brick-panel-probe.img

# The Pixel 2's bootloader: U-Boot and TF-A's BL31 built from source, with
# Rockchip's DDR init and miniloader from rkbin (pinned, checked by sha256), put
# together into buildroot/board/px2/bootloader/u-boot-px2.bin. Rarely needed:
# the result is committed, and `make` only uses it.
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
