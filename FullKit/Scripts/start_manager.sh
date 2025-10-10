#!/bin/bash
# start_manager.sh — activate the DriverKit Manager (idempotent)
set -euo pipefail

LOGFILE="/var/log/macscope-vhid/start_manager.log"
MAN="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*" | tee -a "$LOGFILE"; }

log "Starting DriverKit Manager activation script."

if [[ ! -e "$MAN" ]]; then
  log "Manager binary not found at $MAN"
  exit 1
fi

if [[ ! -x "$MAN" ]]; then
  log "Manager binary is not executable at $MAN"
  exit 1
fi

log "Activating DriverKit via Manager…"
if "$MAN" activate; then
  log "DriverKit Manager activated successfully."
  exit 0
else
  log "Failed to activate DriverKit Manager."
  exit 1
fi
