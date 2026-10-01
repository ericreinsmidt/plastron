# The build host: stock Debian, pinned by digest, with what Buildroot asks of
# a host. Buildroot builds its own cross-compiler and host tools from source,
# so nothing here ends up on the device. The second group is for building
# U-Boot directly (scripts/build-bootloader.sh).
FROM debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

RUN apt-get update && apt-get install -y --no-install-recommends \
        bc bison build-essential ca-certificates cpio file flex git \
        libncurses-dev libssl-dev patch perl python3 rsync unzip wget \
        bzip2 gzip xz-utils \
        python3-dev python3-pyelftools python3-setuptools swig \
        libgnutls28-dev uuid-dev \
    && rm -rf /var/lib/apt/lists/*

# Buildroot refuses to run as root
RUN useradd -m -u 1000 builder
USER builder
WORKDIR /work
