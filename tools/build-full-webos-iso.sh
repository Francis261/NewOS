#!/usr/bin/env bash
set -euo pipefail

# Full live ISO build: boots to Chromium kiosk + local WebOS frontend.
# Works in restricted CI/container environments (no bind-mount requirement).

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_ISO=${1:-$ROOT_DIR/dist/newos-full.iso}
WORKDIR=${WORKDIR:-$ROOT_DIR/.build-full}
CHROOT="$WORKDIR/chroot"
ISO_DIR="$WORKDIR/iso"
DEBIAN_RELEASE=${DEBIAN_RELEASE:-bookworm}
MIRROR=${MIRROR:-http://deb.debian.org/debian}
SQUASHFS_COMP=${SQUASHFS_COMP:-gzip}
SQUASHFS_BLOCK_SIZE=${SQUASHFS_BLOCK_SIZE:-1M}

mkdir -p "$WORKDIR" "$ISO_DIR" "$(dirname "$OUT_ISO")"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)" >&2
  exit 1
fi

apt-get update
apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-common mtools rsync

if [[ ! -d "$CHROOT" ]]; then
  debootstrap --arch=amd64 "$DEBIAN_RELEASE" "$CHROOT" "$MIRROR"
fi

cp /etc/resolv.conf "$CHROOT/etc/resolv.conf"

cat > "$CHROOT/tmp/install-packages.sh" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  systemd-sysv live-boot linux-image-amd64 initramfs-tools \
  xserver-xorg xinit openbox chromium nodejs npm dbus-x11 \
  ca-certificates sudo locales curl
apt-get clean
INNER
chmod +x "$CHROOT/tmp/install-packages.sh"

chroot "$CHROOT" /bin/bash /tmp/install-packages.sh
rm -f "$CHROOT/tmp/install-packages.sh"

mkdir -p "$CHROOT/opt/webos"
rsync -a --delete "$ROOT_DIR/rootfs/opt/webos/" "$CHROOT/opt/webos/"

cat > "$CHROOT/etc/systemd/system/webos-kiosk.service" <<'UNIT'
[Unit]
Description=WebOS Kiosk Session
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/xinit /opt/webos/scripts/start-webos.sh -- :0 vt1
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

chroot "$CHROOT" /bin/bash -lc 'npm config set strict-ssl false && cd /opt/webos/backend && npm install --omit=dev'


chroot "$CHROOT" /bin/bash -lc 'systemctl enable webos-kiosk.service'
chroot "$CHROOT" /bin/bash -lc "echo 'LANG=C.UTF-8' > /etc/default/locale"

KVER=$(chroot "$CHROOT" /bin/bash -lc "ls /lib/modules | sort | tail -n1")
if [[ ! -f "$CHROOT/boot/initrd.img-$KVER" ]]; then
  chroot "$CHROOT" /bin/bash -lc "update-initramfs -u -k $KVER"
fi

mkdir -p "$ISO_DIR/live" "$ISO_DIR/boot/grub"
cp "$CHROOT/boot/vmlinuz-$KVER" "$ISO_DIR/boot/vmlinuz"
cp "$CHROOT/boot/initrd.img-$KVER" "$ISO_DIR/boot/initrd"
cp "$ROOT_DIR/iso/boot/grub/splash.png" "$ISO_DIR/boot/grub/splash.png"

mksquashfs "$CHROOT" "$ISO_DIR/live/filesystem.squashfs" -comp "$SQUASHFS_COMP" -b "$SQUASHFS_BLOCK_SIZE" \
  -e boot tmp var/cache/apt var/lib/apt/lists

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'GRUB'
set default=0
set timeout=0
terminal_output console
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray
menuentry "NewOS Full WebOS" {
  linux /boot/vmlinuz boot=live components quiet splash noeject
  initrd /boot/initrd
}
GRUB

grub-mkrescue -o "$OUT_ISO" "$ISO_DIR"

echo "Full WebOS ISO built at: $OUT_ISO"
ls -lh "$OUT_ISO"

SIZE_BYTES=$(stat -c%s "$OUT_ISO")
echo "ISO size (bytes): $SIZE_BYTES"

if command -v xorriso >/dev/null 2>&1; then
  echo "El Torito boot catalog:"
  xorriso -indev "$OUT_ISO" -report_el_torito plain | sed 's/^/  /'
fi

if [[ "$SIZE_BYTES" -lt 250000000 ]]; then
  echo "WARNING: Full ISO is smaller than expected (<250MB)." >&2
  echo "Verify Chromium/Xorg/live packages were installed into the image." >&2
fi
