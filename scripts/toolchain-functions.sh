build_toolchain() {
  mkdir -p "$PROJ/toolchain/src" "$TOOLCHAIN_BUILD" "$TOOLCHAIN_PREFIX"

  if [ ! -d "$TOOLCHAIN_SRC" ]; then
    git clone --depth 1 --branch "$LLVM_TAG" \
      https://github.com/llvm/llvm-project.git "$TOOLCHAIN_SRC"
  fi

  # The PGO bootstrap compilers must target the host, not the cross sysroot.
  # Keep the native backend available during training; narrow the final build.
  CC=clang CXX=clang++ python3 "$TOOLCHAIN_SRC/llvm/utils/collect_and_build_with_pgo.py" \
    --llvm-dir "$TOOLCHAIN_SRC/llvm" \
    --out-dir "$TOOLCHAIN_BUILD" \
    --cmake-extra-arg "CMAKE_INSTALL_PREFIX=$TOOLCHAIN_PREFIX" \
    --cmake-extra-arg 'CMAKE_C_FLAGS_RELEASE=-O3 -ffast-math -DNDEBUG' \
    --cmake-extra-arg 'CMAKE_CXX_FLAGS_RELEASE=-O3 -ffast-math -DNDEBUG' \
    --cmake-extra-arg 'LLVM_ENABLE_PROJECTS=clang;compiler-rt;lld' \
    --cmake-extra-arg LLVM_ENABLE_LTO=Thin \
    --cmake-extra-arg LLVM_USE_LINKER=lld \
    --cmake-extra-arg LLVM_INSTALL_TOOLCHAIN_ONLY=ON \
    --cmake-extra-arg LLVM_ENABLE_BINDINGS=OFF \
    --cmake-extra-arg LLVM_INCLUDE_BENCHMARKS=OFF \
    --cmake-extra-arg LLVM_INCLUDE_EXAMPLES=OFF

  cmake -B "$TOOLCHAIN_BUILD/optimized" -S "$TOOLCHAIN_SRC/llvm" \
    -DLLVM_TARGETS_TO_BUILD=AArch64 \
    -DLLVM_DEFAULT_TARGET_TRIPLE="$TARGET" \
    -DDEFAULT_SYSROOT="$DEV_DIR" \
    -DCLANG_DEFAULT_LINKER=lld

  ninja -C "$TOOLCHAIN_BUILD/optimized" install

  cd "$TOOLCHAIN_PREFIX/bin"
  llvm_version="$(./clang -dumpversion)"
  llvm_major="${llvm_version%%.*}"
  case "$llvm_major" in
    ''|*[!0-9]*) die "could not determine installed Clang major version: $llvm_version" ;;
  esac
  for tool in clang clang++ llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-ranlib llvm-readelf llvm-strip; do
    # Clang may already install clang-$llvm_major as the real binary.
    [ -e "$tool-$llvm_major" ] || ln -s "$tool" "$tool-$llvm_major"
    ln -sf "$tool" "$TARGET-$tool"
    ln -sf "$tool" "aarch64-linux-musl-$tool"
  done
  [ -e "ld.lld-$llvm_major" ] || ln -s ld.lld "ld.lld-$llvm_major"
  ln -sf ld.lld "$TARGET-ld"
  ln -sf ld.lld "aarch64-linux-musl-ld"

  python3 - "$PROJ/cross.env" "$llvm_major" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
major = sys.argv[2]
tools = {
    "CC": "clang",
    "CXX": "clang++",
    "AR": "llvm-ar",
    "NM": "llvm-nm",
    "RANLIB": "llvm-ranlib",
    "STRIP": "llvm-strip",
    "LD": "ld.lld",
}
text = path.read_text()
for variable, tool in tools.items():
    text, count = re.subn(
        rf'^export {variable}=.*$', f'export {variable}="{tool}-{major}"',
        text, flags=re.MULTILINE,
    )
    if count != 1:
        sys.exit(f"expected exactly one export {variable} in {path}")
path.write_text(text)
PY
}
