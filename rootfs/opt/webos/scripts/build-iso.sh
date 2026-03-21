#!/usr/bin/env bash
set -euo pipefail

# Usage: ./build-iso.sh <kernel> <initrd> [output.iso]
KERNEL=${1:?path to kernel image required}
INITRD=${2:?path to initrd required}
OUTPUT=${3:-webos.iso}
WORKDIR=$(mktemp -d)

mkdir -p "$WORKDIR/boot/grub"
cp "$KERNEL" "$WORKDIR/boot/vmlinuz"
cp "$INITRD" "$WORKDIR/boot/initrd"
cp /opt/webos/assets/splash.png "$WORKDIR/boot/grub/splash.png"
cp /opt/webos/boot/grub.cfg "$WORKDIR/boot/grub/grub.cfg"

grub-mkrescue -o "$OUTPUT" "$WORKDIR"
rm -rf "$WORKDIR"
echo "ISO created: $OUTPUT"
