# AArch64 Gentoo Stage 4 Builder

This project builds an AArch64 Gentoo musl workspace. It separates a development root (`dev/`), used as a chroot and cross-compilation sysroot, from a minimal runtime root (`dist/`).

## Project layout

| Path | Role |
| --- | --- |
| `stage3-*.tar.*` | Gentoo arm64 musl stage 3 archive used to seed `dev/`. |
| `imageBuilder.sh` | Entry point for individual operations and collections. |
| `scripts/` | Operation scripts and shared implementation. |
| `toolchain/` | LLVM source, build, and installation directories for the host cross-compiler. |
| `portage/` | Portage configuration copied into `dev/etc/portage/`; also holds the runtime package list `dist.world`. |
| `binpkgs/` | Shared binary package repository populated by Portage's `FEATURES="buildpkg"`. |
| `dev/` | AArch64 development chroot and cross-compilation sysroot. |
| `dist/` | Runtime root populated from binary packages with development files and Portage state removed. |

## Prerequisites

- A Linux host with root access, tar, Python 3, and AArch64 QEMU user emulation. The script looks for `/usr/bin/qemu-aarch64-static`, falling back to `/usr/bin/qemu-aarch64`; running the chroot also requires appropriately configured binfmt support. A dynamically linked fallback may not work inside the chroot without its host libraries.
- Git, CMake, Ninja, and host Clang and LLD to build LLVM with ThinLTO and PGO.
- `mksquashfs` with zstd support and `zstd` for packing artifacts.
- A Gentoo arm64 musl stage 3 archive named `stage3-*.tar.*` in the project directory. The script uses the first matching archive.
- The LLVM submodule initialized with `git submodule update --init`, or an absent `toolchain/src/llvm-project` directory so the script can clone LLVM itself.

## Usage

Before running any commands, review and configure `scripts/common.sh` for your environment, including the target and LLVM version.
`LLVM_TAG` is used only when the script clones LLVM; an existing checkout or initialized submodule is used as-is. Changing the target away from musl also requires a matching stage 3 and Portage configuration; the toolchain script still creates `aarch64-linux-musl-*` aliases.

Run the following commands from the project directory.

### Initial setup

```sh
sudo ./imageBuilder.sh bootstrap  # Extract stage 3, copy configuration and QEMU, fix symlinks
./imageBuilder.sh toolchain       # Build and install LLVM/Clang/LLD for AArch64
```

`bootstrap` extracts over `dev/`; it does not clear an existing root first. The toolchain's default sysroot is the absolute path to `dev/` at build time.

The toolchain build uses LLVM's PGO helper, `-O3`, `-ffast-math`, and ThinLTO. PGO builds several compiler stages and runs LLVM/Clang tests and a training build, so it requires substantially more time and disk space than a single build. The helper replaces its stage directories under `toolchain/build/` on each run.

Alternatively, `sudo ./imageBuilder.sh setup` runs bootstrap followed by toolchain installation, both as root. Run the individual commands above if the toolchain should be owned by your user.

### Build target packages

```sh
sudo ./imageBuilder.sh chroot
# Inside the chroot:
emerge-webrsync
emerge -av dev-libs/openssl dev-libs/libgpiod
exit
```

The chroot command copies Portage configuration and mounts the necessary filesystems and shared package directory. Portage builds binary packages into `binpkgs/`; after a successful chroot session, the script converts absolute symlinks in `dev/` to relative ones. Use `sudo ./imageBuilder.sh umount` to unmount the filesystems when finished. Bootstrapping and packing alone do not configure a complete stage 4; the development root needs whatever packages and configuration your deployment requires.

### Build the runtime root

Create `portage/dist.world` with one runtime package atom per line; blank lines and lines starting with `#` are ignored. Build those packages and their dependencies in the development chroot first, so their binary packages are available.

```sh
sudo ./imageBuilder.sh build-dist
```

This removes non-hidden contents of `dist/`, installs the manifest using `--usepkgonly` and `RELEASE_INSTALL_MASK`, and removes Portage metadata and caches. It leaves the development mounts in place. Rebuilding `dist/` removes applications previously placed there.

### Cross-compile and pack

```sh
. ./cross.env
$CXX $CXXFLAGS main.cpp $LDFLAGS -Wl,--strip-all -o "$STAGE4_DIST/usr/bin/my-app"
sudo ./imageBuilder.sh pack-dist  # Create aarch64-dist.squashfs
sudo ./imageBuilder.sh pack-dev   # Create aarch64-dev-stage4.tar.zst
```

The example assumes `main.cpp` and `dist/usr/bin/` exist. `cross.env` derives the project path from `$0`, so source it from a shell started in the project directory. A SquashFS root is not a complete bootable system image; boot firmware, kernel, and deployment configuration must be supplied separately.

`pack-dist` removes Portage metadata and caches from `dist/` before packing. `pack-dev` unmounts the development filesystems and **removes the copied QEMU executable from `dev/`**; restore it before using the emulated chroot again.

### Command reference

Pass exactly one command to `./imageBuilder.sh`:

| Command | Action |
| --- | --- |
| `bootstrap` | Extract the stage 3 and prepare the development root. |
| `toolchain` | Build and install the host cross-compiler. |
| `sync-cfg` | Copy `portage/` into the development root. |
| `mount` / `umount` | Mount or unmount development-root filesystems. |
| `chroot` | Sync configuration, mount filesystems, and enter the development root. |
| `fix-links` | Convert absolute symlinks in the development root to relative links. |
| `build-dist` | Rebuild the runtime root from the binary package manifest. |
| `pack-dist` / `pack-dev` | Pack the runtime root or development root. |
| `setup` | Run `bootstrap`, then `toolchain`. |
| `pack` | Run `pack-dist`, then `pack-dev`, with the side effects described above. |

Run `./imageBuilder.sh --help` for the command list. Commands that modify root-owned files or mount filesystems generally require `sudo`.
