#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/myos
export DISPLAY=:0
export XDG_SESSION_TYPE=x11

mkdir -p "$HOME/.config" "$HOME/.cache"
exec /usr/bin/xinit /opt/myos/launch-ui.sh -- :0 vt1 -nolisten tcp
