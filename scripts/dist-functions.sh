build_dist() {
  [ -f "$PORTAGE_CFG/dist.world" ] || die "missing $PORTAGE_CFG/dist.world"

  umount_dev
  rm -rf "${DIST_DIR:?}"/*
  sync_portage_cfg
  mount_dev

  pkgs=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    '' | \#*) continue ;;
    *) pkgs="$pkgs $line" ;;
    esac
  done <"$PORTAGE_CFG/dist.world"

  [ -n "$pkgs" ] || die "no packages listed in $PORTAGE_CFG/dist.world"

  chroot "$DEV_DIR" /bin/bash -c "
        . /etc/portage/make.conf
        INSTALL_MASK=\"\$RELEASE_INSTALL_MASK\" \
        ROOT=/mnt/dist \
        emerge --usepkgonly --oneshot $pkgs
    "

  rm -rf \
    "$DIST_DIR/etc/portage" \
    "$DIST_DIR/var/db/pkg" \
    "$DIST_DIR/var/lib/portage" \
    "$DIST_DIR/var/cache" \
    "$DIST_DIR/var/tmp"/* \
    "$DIST_DIR/tmp"/*
}

pack_dist() {
  rm -rf \
    "$DIST_DIR/etc/portage" \
    "$DIST_DIR/var/db/pkg" \
    "$DIST_DIR/var/lib/portage" \
    "$DIST_DIR/var/cache" \
    "$DIST_DIR/var/tmp"/* \
    "$DIST_DIR/tmp"/*

  mksquashfs "$DIST_DIR" "$PROJ/aarch64-dist.squashfs" \
    -comp zstd -Xcompression-level 19 -noappend -all-root
}

pack_stage4() {
  umount_dev
  rm -f "$DEV_DIR/usr/bin/qemu-aarch64-static"
  tar --xattrs --acls --numeric-owner \
    -cpf "$PROJ/aarch64-dev-stage4.tar.zst" \
    --zstd -C "$DEV_DIR" .
}
