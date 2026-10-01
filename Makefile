# Everything builds in Docker. `make` produces out/sdcard.img, ready to write
# to a card at sector 0.
IMAGE := tortos-px2-builder
VOLUME := tortos-px2-work
DOCKER_RUN := docker run --rm -t -v $(CURDIR):/src:ro -v $(VOLUME):/work $(IMAGE)

.PHONY: all builder volume image shell linux-rebuild copy-out clean-output

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

# Rebuild just the kernel after changing its config, patches or device tree
linux-rebuild: builder volume
	$(DOCKER_RUN) sh /src/scripts/build.sh linux-dirclean all
	$(MAKE) copy-out

copy-out:
	mkdir -p out
	docker run --rm -v $(VOLUME):/work -v $(CURDIR)/out:/out --user root $(IMAGE) \
		sh -c 'cp --sparse=never /work/output/images/sdcard.img /out/ && chown $(shell id -u):$(shell id -g) /out/sdcard.img'
	@ls -l out/sdcard.img

shell: builder volume
	docker run --rm -it -v $(CURDIR):/src:ro -v $(VOLUME):/work $(IMAGE) bash

clean-output:
	docker run --rm -v $(VOLUME):/work $(IMAGE) rm -rf /work/output
