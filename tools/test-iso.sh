#!/usr/bin/env bash
set -euo pipefail

ISO_PATH=${1:-dist/myos-live.iso}
if [[ ! -f "$ISO_PATH" ]]; then
  echo "ISO not found: $ISO_PATH" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

xorriso -indev "$ISO_PATH" -osirrox on -extract /live/filesystem.squashfs "$WORK_DIR/filesystem.squashfs" >/dev/null 2>&1

if [[ ! -f "$WORK_DIR/filesystem.squashfs" ]]; then
  echo "filesystem.squashfs missing from ISO" >&2
  exit 1
fi

unsquashfs -ll "$WORK_DIR/filesystem.squashfs" > "$WORK_DIR/squashfs.lst"

required_paths=(
  "/opt/myos/start.sh"
  "/opt/myos/launch-ui.sh"
  "/etc/systemd/system/myos.service"
  "/opt/myos/bin/myos-shell"
)

for path in "${required_paths[@]}"; do
  if ! grep -Fq "$path" "$WORK_DIR/squashfs.lst"; then
    echo "Required path not found in squashfs: $path" >&2
    exit 1
  fi
done

if grep -Fq "/usr/bin/chromium" "$WORK_DIR/squashfs.lst"; then
  echo "Unexpected Chromium binary found in image; Tauri-only shell expected." >&2
  exit 1
fi

echo "ISO smoke test passed for $ISO_PATH"
