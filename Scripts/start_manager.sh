#!/bin/bash
# start_manager.sh — activate the DriverKit Manager (idempotent)
set -euo pipefail

MAN="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }

if [[ -x "$MAN" ]]; then
  log "Activating DriverKit via Manager…"
  "$MAN" activate || true
else
  echo "Manager binary not found at $MAN" >&2
  exit 1
fi
