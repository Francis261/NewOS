#!/usr/bin/env bash
set -euo pipefail

ISO_DIR=${1:-/root/isolinux}
mkdir -p "$ISO_DIR"

find_asset() {
  local pattern=$1
  local pkg=$2
  local path

  path=$(dpkg -L "$pkg" 2>/dev/null | rg "$pattern" -m1 || true)
  if [[ -n "$path" && -f "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  path=$(find /usr/lib -type f | rg "$pattern" -m1 || true)
  if [[ -n "$path" && -f "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  return 1
}

iso_bin=$(find_asset '/isolinux\.bin$' isolinux || true)
menu_bin=$(find_asset '/vesamenu\.c32$' syslinux-common || true)

if [[ -z "$iso_bin" ]]; then
  echo "isolinux.bin not found (install package: isolinux)" >&2
  exit 1
fi

if [[ -z "$menu_bin" ]]; then
  echo "vesamenu.c32 not found (install package: syslinux-common)" >&2
  exit 1
fi

cp -f "$iso_bin" "$ISO_DIR/isolinux.bin"
cp -f "$menu_bin" "$ISO_DIR/vesamenu.c32"

echo "Prepared isolinux assets in $ISO_DIR"
