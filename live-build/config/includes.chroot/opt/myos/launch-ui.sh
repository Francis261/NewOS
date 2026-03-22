#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/myos
export DISPLAY=:0
export WEBKIT_DISABLE_DMABUF_RENDERER=1

xset -dpms
xset s off
xset s noblank
openbox-session &

# Primary path: native Tauri shell binary dropped in /opt/myos/bin
if [[ -x /opt/myos/bin/myos-shell ]]; then
  exec /opt/myos/bin/myos-shell --kiosk
fi

# Secondary path: static React build via Chromium kiosk
if [[ -f /opt/myos/ui/index.html ]]; then
  exec chromium --kiosk --no-first-run --disable-session-crashed-bubble \
    --disable-infobars file:///opt/myos/ui/index.html
fi

# Fallback diagnostic view
exec xterm -fa 'Monospace' -fs 12 -e "echo 'MyOS UI not found at /opt/myos/bin/myos-shell or /opt/myos/ui/index.html'; bash"
