#!/bin/sh
# Derives buildroot/board/px2/linux.config from ROCKNIX's config
# (linux.config.rocknix) and our changes (linux-px2.config). Runs in the
# build container against a kernel tree with our patches applied, since
# some of the options only exist once they are:
#
#   sh /src/scripts/kernel-config.sh /work/output/build/linux-7.1.2
set -eu

TREE=$1
BOARD=/src/buildroot/board/px2
cd "$TREE"

cp "$BOARD/linux.config.rocknix" .config
# Nothing loads modules here: every module goes, unless linux-px2.config
# builds it in
sed -i 's/^\(CONFIG_[A-Za-z0-9_]*\)=m$/# \1 is not set/' .config
scripts/kconfig/merge_config.sh -m -O . .config "$BOARD/linux-px2.config" >/dev/null
make ARCH=arm64 olddefconfig >/dev/null

# merge_config warns about requests olddefconfig overrode; say which
grep -E "^(# )?CONFIG_" "$BOARD/linux-px2.config" | sed -E 's/^# (CONFIG_[A-Za-z0-9_]+) is not set/\1=n/' |
while IFS== read -r symbol want; do
	got=$(grep -E "^$symbol=" .config | cut -d= -f2)
	[ -n "$got" ] || got=n
	[ "$got" = "$want" ] || echo "note: $symbol is $got, not $want" >&2
done

cp .config "$BOARD/linux.config"
echo "linux.config: $(grep -c '=y$' .config) built in, $(grep -c '=m$' .config) modules"
