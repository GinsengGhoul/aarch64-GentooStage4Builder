#!/bin/dash
set -eu

. "$(dirname -- "$0")/common.sh"

stage3_tar=""
for f in "$PROJ"/stage3-*.tar.*; do
  if [ -f "$f" ]; then
    stage3_tar="$f"
    break
  fi
done
[ -n "$stage3_tar" ] || { printf 'error: no stage3-*.tar.* archive found in %s\n' "$PROJ" >&2; exit 1; }

mkdir -p "$DEV_DIR" "$PROJ/dist" "$PROJ/binpkgs"
printf 'Extracting %s into %s...\n' "$stage3_tar" "$DEV_DIR"
tar --xattrs-include='*.*' --numeric-owner -xpf "$stage3_tar" -C "$DEV_DIR"

sync_portage_cfg
cp --dereference /etc/resolv.conf "$DEV_DIR/etc/resolv.conf"

if [ -x /usr/bin/qemu-aarch64-static ]; then
  cp /usr/bin/qemu-aarch64-static "$DEV_DIR/usr/bin/"
elif [ -x /usr/bin/qemu-aarch64 ]; then
  cp /usr/bin/qemu-aarch64 "$DEV_DIR/usr/bin/qemu-aarch64-static"
else
  printf 'error: qemu-aarch64-static not found on host\n' >&2
  exit 1
fi

fix_dev_symlinks
