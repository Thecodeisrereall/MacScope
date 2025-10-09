#!/bin/bash
# bringup.sh — one prompt: build client (if needed), activate, ensure daemon, create keyboard, test key
set -euo pipefail

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
die(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run with administrator privileges."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR"
BUILD="$ROOT/build_custom_client.sh"
BIN="/usr/local/bin/macscope-vhid"
MAN="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
DAE="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
SOCK_DIR="/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"

# 1) Build client if missing
if [[ ! -x "$BIN" ]]; then
  [[ -x "$BUILD" ]] || die "Missing $BUILD"
  log "Client missing — building custom client…"
  "$BUILD"
fi

# 2) Activate Manager (idempotent)
if [[ -x "$MAN" ]]; then
  log "Activating DriverKit via Manager…"
  "$MAN" activate || true
fi

# 3) Ensure daemon running (idempotent)
if pgrep -fl "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
  log "Daemon already running."
else
  log "Starting daemon…"
  nohup "$DAE" >/dev/null 2>&1 & disown || die "Failed to launch daemon."
  sleep 2
fi

# 4) Wait for socket (short grace)
for i in {1..15}; do
  if compgen -G "$SOCK_DIR"/*.sock > /dev/null; then break; fi
  sleep 0.2
done

# 5) Create keyboard + tap 'A'
log "Creating virtual keyboard…"
"$BIN" create-keyboard --country us

log "Sending test key: A (0x04) down/up…"
"$BIN" key down --usage 0x04
sleep 0.05
"$BIN" key up   --usage 0x04

log "Bring-up complete ✅"
