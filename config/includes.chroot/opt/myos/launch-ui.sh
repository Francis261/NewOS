#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/myos
export DISPLAY=:0

xset -dpms
xset s off
xset s noblank
openbox-session &

# Tauri-first shell: /opt/myos/bin/myos-shell should resolve to your packaged app.
exec /opt/myos/bin/myos-shell
