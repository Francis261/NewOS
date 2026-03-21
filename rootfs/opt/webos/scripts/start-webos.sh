#!/bin/sh
set -eu

export DISPLAY=:0
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
mkdir -p "$XDG_RUNTIME_DIR"

cd /opt/webos/backend
if [ ! -d node_modules ]; then
  if [ -f package-lock.json ]; then
    npm ci --omit=dev
  else
    npm install --omit=dev
  fi
fi
node server.js >/var/log/webos-backend.log 2>&1 &

sleep 1

TAURI_BIN="${TAURI_BIN:-/opt/webos/tauri/target/release/webos-shell}"
if [ ! -x "$TAURI_BIN" ]; then
  echo "Tauri shell binary not found at $TAURI_BIN" >&2
  echo "Build it with: cd /opt/webos/tauri && cargo tauri build" >&2
  exit 1
fi

exec "$TAURI_BIN"
