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

MOUNTED=()
cleanup_mounts() {
  for mp in "${MOUNTED[@]}"; do
    if mountpoint -q "$mp"; then
      umount "$mp" || true
    fi
  done
}
trap cleanup_mounts EXIT

apt-get update
apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-common mtools rsync

if [[ ! -d "$CHROOT" ]]; then
  debootstrap --arch=amd64 "$DEBIAN_RELEASE" "$CHROOT" "$MIRROR"
fi

cp /etc/resolv.conf "$CHROOT/etc/resolv.conf"

for mp in proc sys dev; do
  mkdir -p "$CHROOT/$mp"
done

if ! mountpoint -q "$CHROOT/proc"; then
  mount -t proc proc "$CHROOT/proc"
  MOUNTED+=("$CHROOT/proc")
fi
if ! mountpoint -q "$CHROOT/sys"; then
  mount --bind /sys "$CHROOT/sys"
  MOUNTED+=("$CHROOT/sys")
fi
if ! mountpoint -q "$CHROOT/dev"; then
  mount --bind /dev "$CHROOT/dev"
  MOUNTED+=("$CHROOT/dev")
fi

cat > "$CHROOT/tmp/install-packages.sh" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  systemd-sysv live-boot linux-image-amd64 initramfs-tools \
  xserver-xorg xinit openbox nodejs npm dbus-x11 \
  libwebkit2gtk-4.1-0 libgtk-3-0 libayatana-appindicator3-1 \
  libwebkit2gtk-4.1-dev libgtk-3-dev libglib2.0-dev libayatana-appindicator3-dev \
  build-essential gcc g++ libc6-dev pkg-config \
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

chroot "$CHROOT" /bin/bash -lc '
set -euo pipefail
npm config set strict-ssl false
npm config set fund false
npm config set audit false
npm config set update-notifier false
for i in 1 2 3; do
  (cd /opt/webos/backend && npm install --omit=dev --no-audit --no-fund) && break
  echo "backend npm install failed (attempt $i/3), retrying..."
  npm cache verify || true
  npm cache clean --force || true
  sleep 2
  if [[ "$i" -eq 3 ]]; then
    echo "backend npm install failed after retries" >&2
    exit 1
  fi
done
'

chroot "$CHROOT" /bin/bash -lc '
set -euo pipefail
npm config set strict-ssl false
npm config set fund false
npm config set audit false
npm config set update-notifier false
for i in 1 2 3; do
  (cd /opt/webos/tauri/frontend && npm install --no-audit --no-fund && npm run build) && break
  echo "tauri frontend npm build failed (attempt $i/3), retrying..."
  npm cache verify || true
  npm cache clean --force || true
  sleep 2
  if [[ "$i" -eq 3 ]]; then
    echo "tauri frontend npm build failed after retries" >&2
    exit 1
  fi
done
'
chroot "$CHROOT" /bin/bash -lc '
set -euo pipefail
if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
  curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
fi
. "$HOME/.cargo/env"
rustup toolchain install stable --profile minimal
rustup default stable
cd /opt/webos/tauri
if ! command -v gcc >/dev/null 2>&1; then
  echo "gcc not found; cannot compile Rust dependencies" >&2
  exit 1
fi
export CC=gcc
export CXX=g++
export RUSTFLAGS="${RUSTFLAGS:-} -C linker=gcc"
cargo build --release
'


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
