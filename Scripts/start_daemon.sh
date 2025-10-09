#!/bin/bash
# start_daemon.sh — start the Karabiner VirtualHIDDevice daemon (requires admin)
set -euo pipefail

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
die(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; exit 1; }

DAE="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  # Try non-interactive sudo first
  if sudo -n true 2>/dev/null; then
    exec sudo "$0" "$@"
  else
    die "Please run with administrator privileges (e.g. via bringup.sh)."
  fi
fi

if pgrep -fl "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
  log "Daemon already running."
else
  log "Starting daemon…"
  nohup "$DAE" >/dev/null 2>&1 & disown || die "Failed to launch daemon."
fi
