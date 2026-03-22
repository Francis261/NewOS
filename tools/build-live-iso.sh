#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
LB_DIR="$ROOT_DIR/live-build"
OUT_DIR="$ROOT_DIR/dist"

mkdir -p "$OUT_DIR"
cd "$LB_DIR"

if ! command -v lb >/dev/null 2>&1; then
  echo "live-build is required. Install with: sudo apt-get install -y live-build" >&2
  exit 1
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo ./tools/build-live-iso.sh" >&2
  exit 1
fi

lb clean --purge || true
lb config noauto \
  --mode debian \
  --distribution bookworm \
  --parent-distribution bookworm \
  --parent-debian-installer-distribution bookworm \
  --architectures amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --parent-mirror-bootstrap http://deb.debian.org/debian \
  --parent-mirror-chroot http://deb.debian.org/debian \
  --parent-mirror-binary http://deb.debian.org/debian \
  --mirror-bootstrap http://deb.debian.org/debian \
  --mirror-chroot http://deb.debian.org/debian \
  --mirror-binary http://deb.debian.org/debian \
  --mirror-chroot-security http://security.debian.org/debian-security \
  --mirror-binary-security http://security.debian.org/debian-security \
  --debian-installer false \
  --binary-images iso-hybrid \
  --bootappend-live "boot=live components quiet splash username=myos hostname=myos" \
  --memtest none \
  --apt-indices false \
  --apt-recommends false \
  --cache true \
  --cache-packages true
lb build

if [[ -f live-image-amd64.hybrid.iso ]]; then
  cp -f live-image-amd64.hybrid.iso "$OUT_DIR/myos-live.iso"
  echo "ISO ready at $OUT_DIR/myos-live.iso"
else
  echo "Build finished but ISO was not found." >&2
  exit 1
fi
