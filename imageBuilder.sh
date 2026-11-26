#!/bin/dash
set -eu
PROJ="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

usage() {
  printf '%s\n' "Usage: $0 {bootstrap|toolchain|sync-cfg|mount|umount|chroot|fix-links|build-dist|pack-dist|pack-dev|setup|pack}"
  printf '%s\n' 'Collections: setup = bootstrap + toolchain; pack = pack-dist + pack-dev'
}

[ "$#" -eq 1 ] || { usage >&2; exit 1; }
case "$1" in
bootstrap) "$PROJ/scripts/bootstrap.sh" ;;
toolchain|sync-cfg|mount|umount|chroot|fix-links|build-dist|pack-dist|pack-dev)
  "$PROJ/scripts/$1.sh" ;;
setup)
  "$PROJ/scripts/bootstrap.sh"
  "$PROJ/scripts/toolchain.sh" ;;
pack)
  "$PROJ/scripts/pack-dist.sh"
  "$PROJ/scripts/pack-dev.sh" ;;
help|--help|-h) usage ;;
*) usage >&2; exit 1 ;;
esac
