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
  for tool in clang clang++ llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-ranlib llvm-readelf llvm-strip; do
    ln -sf "$tool" "$TARGET-$tool"
    ln -sf "$tool" "aarch64-linux-musl-$tool"
  done
  ln -sf ld.lld "$TARGET-ld"
  ln -sf ld.lld "aarch64-linux-musl-ld"
}
