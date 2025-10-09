#!/bin/bash
# root_phase.sh — single elevation: activate Manager, ensure daemon, run real ping
set -euo pipefail
MAN="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
DAE="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
BIN="/usr/local/bin/macscope-vhid"
ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
err(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; }
[[ ${EUID:-$(id -u)} -eq 0 ]] || { err "Run with administrator privileges"; exit 1; }

# Activate driver (non-fatal)
if [[ -x "$MAN" ]]; then "$MAN" activate || true; fi

# Ensure daemon
if pgrep -fl "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
  log "Daemon already running."
else
  log "Starting daemon…"
  nohup "$DAE" >/dev/null 2>&1 &
  sleep 2
fi

# Real protocol ping
if [[ -x "$BIN" ]]; then
  "$BIN" ping
else
  err "macscope-vhid not installed; run Scripts/build_custom_client.sh"
  exit 1
fi
