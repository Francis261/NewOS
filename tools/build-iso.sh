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
./tools/prepare-isolinux-assets.sh

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
