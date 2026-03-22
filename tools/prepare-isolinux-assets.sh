#!/usr/bin/env bash
set -euo pipefail

ISO_DIR=${1:-/root/isolinux}
mkdir -p "$ISO_DIR"

find_from_dpkg() {
  local pkg=$1
  local suffix=$2
  local path

  path=$(dpkg -L "$pkg" 2>/dev/null | grep -E "${suffix}$" | head -n1 || true)
  if [[ -n "$path" && -f "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  return 1
}

find_from_fs() {
  local filename=$1
  local path

  path=$(find /usr/lib -type f -name "$filename" -print -quit 2>/dev/null || true)
  if [[ -n "$path" && -f "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  return 1
}

iso_bin=$(find_from_dpkg isolinux '/isolinux\.bin' || find_from_fs isolinux.bin || true)
menu_bin=$(find_from_dpkg syslinux-common '/vesamenu\.c32' || find_from_fs vesamenu.c32 || true)

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
