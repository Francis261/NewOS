#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/myos
export DISPLAY=:0

xset -dpms
xset s off
xset s noblank
openbox-session &

# Configurable lock-down (set MYOS_KIOSK_LOCKDOWN=0 to disable shortcuts).
LOCKDOWN=${MYOS_KIOSK_LOCKDOWN:-1}
CHROME_FLAGS=(--kiosk --no-first-run --disable-infobars --disable-session-crashed-bubble)
if [[ "$LOCKDOWN" = "1" ]]; then
  CHROME_FLAGS+=(--overscroll-history-navigation=0 --incognito)
fi

# Preferred: packaged Tauri shell binary copied at build time
if [[ -x /opt/myos/bin/myos-shell ]]; then
  exec /opt/myos/bin/myos-shell --kiosk
fi

# Fallback: React desktop served from static files in Chromium kiosk
if [[ -f /opt/myos/ui/index.html ]]; then
  exec chromium "${CHROME_FLAGS[@]}" file:///opt/myos/ui/index.html
fi

exec xterm -e "echo 'No UI payload found in /opt/myos/bin or /opt/myos/ui'; bash"
