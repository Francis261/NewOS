#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/myos
export XDG_SESSION_TYPE=x11
export DISPLAY=:0

mkdir -p "$HOME/.cache" "$HOME/.config/openbox"

exec /usr/bin/xinit /opt/myos/launch-ui.sh -- :0 vt1 -nolisten tcp
