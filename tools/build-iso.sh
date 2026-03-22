#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR="$ROOT_DIR/dist"
mkdir -p "$OUT_DIR"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo ./tools/build-iso.sh" >&2
  exit 1
fi

if ! command -v lb >/dev/null 2>&1; then
  echo "Install live-build first: apt-get install -y live-build debootstrap xorriso squashfs-tools" >&2
  exit 1
fi

if [[ ! -f /usr/share/keyrings/debian-archive-keyring.gpg ]]; then
  echo "Warning: debian-archive-keyring not found; install it to avoid signature warnings." >&2
fi

cd "$ROOT_DIR"

prepare_isolinux_assets() {
  local iso_dir="/root/isolinux"
  mkdir -p "$iso_dir"

  if [[ ! -f "$iso_dir/isolinux.bin" ]]; then
    local iso_bin
    iso_bin=$(dpkg -L isolinux 2>/dev/null | rg '/isolinux\.bin$' -m1 || true)
    if [[ -n "$iso_bin" && -f "$iso_bin" ]]; then
      cp -f "$iso_bin" "$iso_dir/isolinux.bin"
    fi
  fi

  if [[ ! -f "$iso_dir/vesamenu.c32" ]]; then
    local menu_bin
    menu_bin=$(dpkg -L syslinux-common 2>/dev/null | rg '/vesamenu\.c32$' -m1 || true)
    if [[ -n "$menu_bin" && -f "$menu_bin" ]]; then
      cp -f "$menu_bin" "$iso_dir/vesamenu.c32"
    fi
  fi
}

prepare_isolinux_assets

lb clean --purge || true
./config/auto/config
lb build

ISO_NAME=live-image-amd64.hybrid.iso
if [[ ! -f "$ISO_NAME" ]]; then
  echo "ISO not found: $ISO_NAME" >&2
  exit 1
fi

cp -f "$ISO_NAME" "$OUT_DIR/myos-live.iso"
echo "Built: $OUT_DIR/myos-live.iso"
