PROJ="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TOOLCHAIN_SRC="$PROJ/toolchain/src/llvm-project"
TOOLCHAIN_BUILD="$PROJ/toolchain/build"
TOOLCHAIN_PREFIX="$PROJ/toolchain/install"
DEV_DIR="$PROJ/dev"
DIST_DIR="$PROJ/dist"
BINPKGS_DIR="$PROJ/binpkgs"
PORTAGE_CFG="$PROJ/portage"
# For a non-musl system, change the target triple and use a matching stage 3
# and compatible Portage configuration; the triple alone does not change libc.
TARGET="aarch64-gentoo-linux-musl"
LLVM_TAG="llvmorg-23.1.6"

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

. "$PROJ/scripts/dev-functions.sh"
. "$PROJ/scripts/toolchain-functions.sh"
. "$PROJ/scripts/dist-functions.sh"
