#!/bin/bash
# restart.sh — restart daemon (root), re-activate manager
set -euo pipefail

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
die(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run with administrator privileges."

MAN="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
DAE="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"

log "Stopping daemon (if running)…"
pkill -f "Karabiner-VirtualHIDDevice-Daemon" || true
sleep 1

log "Re-activating Manager…"
[[ -x "$MAN" ]] && "$MAN" activate || true

log "Starting daemon…"
nohup "$DAE" >/dev/null 2>&1 & disown || die "Failed to launch daemon."

log "Restart complete ✅"
