build_toolchain() {
  mkdir -p "$PROJ/toolchain/src" "$TOOLCHAIN_BUILD" "$TOOLCHAIN_PREFIX"

  if [ ! -d "$TOOLCHAIN_SRC" ]; then
    git clone --depth 1 --branch "$LLVM_TAG" \
      https://github.com/llvm/llvm-project.git "$TOOLCHAIN_SRC"
  fi

  cmake -G Ninja -B "$TOOLCHAIN_BUILD" -S "$TOOLCHAIN_SRC/llvm" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$TOOLCHAIN_PREFIX" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="AArch64" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="$TARGET" \
    -DDEFAULT_SYSROOT="$DEV_DIR" \
    -DCLANG_DEFAULT_LINKER=lld \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF

  ninja -C "$TOOLCHAIN_BUILD" install

  cd "$TOOLCHAIN_PREFIX/bin"
  for tool in clang clang++ llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-ranlib llvm-readelf llvm-strip; do
    ln -sf "$tool" "$TARGET-$tool"
    ln -sf "$tool" "aarch64-linux-musl-$tool"
  done
  ln -sf ld.lld "$TARGET-ld"
  ln -sf ld.lld "aarch64-linux-musl-ld"
}
