#!/bin/bash
# _common.sh — shared utilities for MacScope Scripts
set -euo pipefail

LOG_TAG="[MacScope]"
ts() { date "+%Y-%m-%d %H:%M:%S"; }
log()   { printf "%s %s %s\n" "$(ts)" "$LOG_TAG" "$*"; }
warn()  { printf "%s %s [WARN] %s\n" "$(ts)" "$LOG_TAG" "$*" >&2; }
error() { printf "%s %s [ERROR] %s\n" "$(ts)" "$LOG_TAG" "$*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 1; }; }
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || { error "Run as root (use sudo)"; exit 1; }; }

# Paths
KARB_MANAGER="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
KARB_DAEMON="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
SOCKET_DIR="/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"
VHIDCTL="/usr/local/bin/vhidctl"

# Local kit (download destination managed by ScriptsBootstrap.swift)
KIT_DIR="${HOME}/Library/MacScope_vHID_Kit"
MANIFEST="${KIT_DIR}/manifest.json"

# Helpers
is_running() { pgrep -fl "$1" >/dev/null 2>&1; }

# Run vhidctl with sudo if needed (client must be root, per README)
run_vhidctl() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    sudo "${VHIDCTL}" "$@"
  else
    "${VHIDCTL}" "$@"
  fi
}
