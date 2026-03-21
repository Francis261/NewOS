#!/usr/bin/env bash
set -euo pipefail

OUT=${1:-dist/newos-immediate.iso}
WORK=$(mktemp -d)
INITDIR=$(mktemp -d)
KERNEL=${KERNEL_IMAGE:-/boot/vmlinuz}

if [[ ! -f "$KERNEL" ]]; then
  echo "Kernel image not found at $KERNEL" >&2
  exit 1
fi

mkdir -p "$INITDIR"/{bin,sbin,etc,proc,sys,dev,tmp,opt/webos}
cp /usr/bin/busybox "$INITDIR/bin/busybox"
for app in sh mount mkdir mknod sleep echo cat; do
  ln -sf /bin/busybox "$INITDIR/bin/$app"
done

cat > "$INITDIR/init" <<'INIT'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev || {
  mkdir -p /dev
  mknod /dev/console c 5 1
  mknod /dev/null c 1 3
}
echo "NewOS bootstrap initramfs loaded."
echo "This ISO verifies kernel+GRUB boot path."
echo "For full WebOS UI boot, use Buildroot image with Chromium/Xorg from README."
exec sh
INIT
chmod +x "$INITDIR/init"

( cd "$INITDIR" && find . -print0 | cpio --null -ov --format=newc | gzip -9 ) > "$WORK/initrd"

mkdir -p "$WORK/boot/grub"
cp "$KERNEL" "$WORK/boot/vmlinuz"
cp "$WORK/initrd" "$WORK/boot/initrd"
cp iso/boot/grub/splash.png "$WORK/boot/grub/splash.png"
cat > "$WORK/boot/grub/grub.cfg" <<'CFG'
set default=0
set timeout=0
terminal_output console
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray
menuentry "NewOS Immediate Boot" {
    linux /boot/vmlinuz quiet loglevel=3
    initrd /boot/initrd
}
CFG

grub-mkrescue -o "$OUT" "$WORK" >/tmp/grub-mkrescue.log 2>&1

echo "Built ISO: $OUT"
ls -lh "$OUT"

SIZE_BYTES=$(stat -c%s "$OUT")
echo "ISO size (bytes): $SIZE_BYTES"

if command -v xorriso >/dev/null 2>&1; then
  echo "El Torito boot catalog:"
  xorriso -indev "$OUT" -report_el_torito plain | sed 's/^/  /'
fi

if [[ "$SIZE_BYTES" -lt 4000000 ]]; then
  echo "WARNING: ISO is very small (<4MB)." >&2
  echo "This can still be valid for the immediate build (kernel+initramfs sanity image)." >&2
fi
