# The TrimUI Brick's boot loader builds here: U-Boot and TF-A (see
# scripts/build-brick-bootloader.sh). Debian 13 with its own GCC 14, the
# compiler the Brick's boot loader was tested with, and packages from
# Debian's snapshot archive as of 2026-10-11, so the image comes out the same
# whenever it's built.
FROM debian@sha256:913f6706df59a68922d1dd08f78c2476560a8d367897200a6005b00e5f67c2d5

RUN rm -f /etc/apt/sources.list.d/* && \
	echo 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20261011T060000Z trixie main' > /etc/apt/sources.list && \
	echo 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20261011T060000Z trixie-security main' >> /etc/apt/sources.list && \
	apt-get update && apt-get install -y --no-install-recommends \
		build-essential bison flex bc ca-certificates wget libssl-dev \
		libgnutls28-dev python3 python3-dev python3-setuptools \
		python3-pyelftools swig device-tree-compiler uuid-dev && \
	rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 builder
USER builder
