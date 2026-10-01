# Everything builds in Docker. `make` produces out/sdcard.img, TortOS on the
# base Pixel 2 system, ready to write to a card at sector 0. `make base`
# produces out/sdcard-base.img, the base system alone.
IMAGE := tortos-px2-builder
VOLUME := tortos-px2-work
# The x86 packing step runs on the same Debian the builder starts from
BASE_IMAGE := debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251
DOCKER_RUN := docker run --rm -t -v $(CURDIR):/src:ro -v $(VOLUME):/work $(IMAGE)

.PHONY: all builder volume image base bootloader shell linux-rebuild copy-out clean-output

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
	docker run --rm -t -e FLAVOR=base -v $(CURDIR):/src:ro -v $(VOLUME):/work $(IMAGE) sh /src/scripts/build.sh
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

OUTPUT ?= output
CARD ?= sdcard.img
copy-out:
	mkdir -p out
	docker run --rm -v $(VOLUME):/work -v $(CURDIR)/out:/out --user root $(IMAGE) \
		sh -c 'cp --sparse=never /work/$(OUTPUT)/images/sdcard.img /out/$(CARD) && chown $(shell id -u):$(shell id -g) /out/$(CARD)'
	@ls -l out/$(CARD)

shell: builder volume
	docker run --rm -it -v $(CURDIR):/src:ro -v $(VOLUME):/work $(IMAGE) bash

clean-output:
	docker run --rm -v $(VOLUME):/work $(IMAGE) rm -rf /work/output
