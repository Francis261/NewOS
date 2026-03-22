#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR="$ROOT_DIR/dist"
TMP_BINARY_DIR="$ROOT_DIR/.myos-binary-tmp"
mkdir -p "$OUT_DIR"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo ./tools/build-iso.sh" >&2
  exit 1
fi

if ! command -v lb >/dev/null 2>&1; then
  echo "Install live-build first: apt-get install -y live-build debootstrap xorriso squashfs-tools" >&2
  exit 1
fi

cd "$ROOT_DIR"

cleanup() {
  if [[ -d "$TMP_BINARY_DIR" ]]; then
    mkdir -p config/binary
    cp -a "$TMP_BINARY_DIR"/. config/binary/
    rm -rf "$TMP_BINARY_DIR"
  fi
}
trap cleanup EXIT

# Keep requested repository layout (config/binary) but stage assets where live-build expects them.
if [[ -d config/binary ]]; then
  rm -rf "$TMP_BINARY_DIR"
  mkdir -p "$TMP_BINARY_DIR"
  cp -a config/binary/. "$TMP_BINARY_DIR"/
  rm -rf config/binary
fi

rm -rf config/includes.binary
mkdir -p config/includes.binary
if [[ -d "$TMP_BINARY_DIR" ]]; then
  cp -a "$TMP_BINARY_DIR"/. config/includes.binary/
fi

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
