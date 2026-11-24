#!/usr/bin/env bash

# Delay (seconds) between launches; override with STARTUP_DELAY=2 ./startup.sh
DELAY="${STARTUP_DELAY:-1}"

# Background kitty so the script doesn't block until it's closed.
kitty --start-as=maximized >/dev/null 2>&1 &
disown

sleep "$DELAY"

# Open apps on their own workspaces in the background ("silent" = don't switch to them).

hyprctl dispatch 'hl.dsp.exec_cmd("firefox", { workspace = "2 silent" })' >/dev/null

sleep "$DELAY"

hyprctl dispatch 'hl.dsp.exec_cmd("code", { workspace = "3 silent" })' >/dev/null
