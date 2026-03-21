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

CHROMIUM_BIN="$(command -v chromium-browser || true)"
if [ -z "$CHROMIUM_BIN" ]; then
  CHROMIUM_BIN="$(command -v chromium || true)"
fi
if [ -z "$CHROMIUM_BIN" ]; then
  echo "Chromium binary not found (expected chromium-browser or chromium)" >&2
  exit 1
fi

exec "$CHROMIUM_BIN" \
  --kiosk \
  --no-first-run \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-features=TranslateUI,BackForwardCache,AutofillServerCommunication \
  --disable-background-networking \
  --disable-sync \
  --disk-cache-size=10485760 \
  --media-cache-size=10485760 \
  --process-per-site \
  --overscroll-history-navigation=0 \
  http://127.0.0.1:8080/index.html
