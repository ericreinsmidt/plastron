# The TrimUI Brick's kernel builds here (scripts/build-brick-kernel.sh):
# Allwinner's Linux 4.9 needs GCC 10, which Buildroot's toolchain isn't.
# Debian 11's last image, with packages from its archive, which no longer
# changes, so the image comes out the same whenever it's built.
FROM debian@sha256:6f519a81440354a85eb592c5f32109ab80605f6b892455983a6f618bf87fabe9

RUN printf 'deb http://archive.debian.org/debian bullseye main\ndeb http://archive.debian.org/debian-security bullseye-security main\n' > /etc/apt/sources.list && \
	rm -f /etc/apt/sources.list.d/* && \
	apt-get -o Acquire::Check-Valid-Until=false update && \
	apt-get install -y --no-install-recommends \
		gcc-10 make bc bison flex libssl-dev libelf-dev cpio kmod xz-utils \
		ca-certificates wget patch python3 device-tree-compiler file && \
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 10 && \
	update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-10 10 && \
	rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 builder
USER builder
