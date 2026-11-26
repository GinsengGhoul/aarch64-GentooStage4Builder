sync_portage_cfg() {
  [ -d "$DEV_DIR/etc/portage" ] || die "$DEV_DIR is not initialized"
  cp -a "$PORTAGE_CFG"/. "$DEV_DIR/etc/portage/"
}

fix_dev_symlinks() {
  python3 -c '
import os, sys

sysroot = os.path.abspath(sys.argv[1])
skip = (
    os.path.join(sysroot, "proc"),
    os.path.join(sysroot, "sys"),
    os.path.join(sysroot, "dev"),
    os.path.join(sysroot, "var/cache/binpkgs"),
    os.path.join(sysroot, "mnt/dist"),
)

for root, dirs, files in os.walk(sysroot):
    if any(root == s or root.startswith(s + os.sep) for s in skip):
        continue
    for name in files + dirs:
        path = os.path.join(root, name)
        if os.path.islink(path):
            target = os.readlink(path)
            if target.startswith("/"):
                rel_target = os.path.relpath(sysroot + target, root)
                os.unlink(path)
                os.symlink(rel_target, path)
' "$DEV_DIR"
}

mount_dev() {
  mkdir -p "$DEV_DIR/var/cache/binpkgs" "$DEV_DIR/mnt/dist"
  mountpoint -q "$DEV_DIR/proc" || mount --types proc /proc "$DEV_DIR/proc"
  if ! mountpoint -q "$DEV_DIR/sys"; then
    mount --rbind /sys "$DEV_DIR/sys"
    mount --make-rslave "$DEV_DIR/sys"
  fi
  if ! mountpoint -q "$DEV_DIR/dev"; then
    mount --rbind /dev "$DEV_DIR/dev"
    mount --make-rslave "$DEV_DIR/dev"
  fi
  mountpoint -q "$DEV_DIR/var/cache/binpkgs" || mount --bind "$BINPKGS_DIR" "$DEV_DIR/var/cache/binpkgs"
  mountpoint -q "$DEV_DIR/mnt/dist" || mount --bind "$DIST_DIR" "$DEV_DIR/mnt/dist"
}

umount_dev() {
  for m in "$DEV_DIR/mnt/dist" "$DEV_DIR/var/cache/binpkgs"; do
    if mountpoint -q "$m"; then
      umount "$m"
    fi
  done
  for m in "$DEV_DIR/dev" "$DEV_DIR/sys" "$DEV_DIR/proc"; do
    if mountpoint -q "$m"; then
      umount -R "$m"
    fi
  done
}

enter_chroot() {
  sync_portage_cfg
  mount_dev
  chroot "$DEV_DIR" /bin/bash -l
  fix_dev_symlinks
}
