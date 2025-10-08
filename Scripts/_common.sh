#!/bin/bash
# _common.sh — shared utilities for MacScope Scripts
set -euo pipefail

LOG_TAG="[MacScope]"

ts() { date "+%Y-%m-%d %H:%M:%S"; }

log()   { printf "%s %s %s\n" "$(ts)" "$LOG_TAG" "$*"; }
warn()  { printf "%s %s [WARN] %s\n" "$(ts)" "$LOG_TAG" "$*" >&2; }
error() { printf "%s %s [ERROR] %s\n" "$(ts)" "$LOG_TAG" "$*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 1; }
}

confirm() {
  local prompt="$1" default="${2:-N}" ans
  read -r -p "$prompt [y/${default}]: " ans || true
  ans="${ans,,}"
  if [[ -z "$ans" ]]; then
    [[ "$default" == "Y" || "$default" == "y" ]] && return 0 || return 1
  fi
  [[ "$ans" == "y" || "$ans" == "yes" ]]
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    error "This script must run as root. Re-run with sudo."
    exit 1
  fi
}

# Paths
KARB_MANAGER="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
KARB_DAEMON="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
SOCKET_DIR="/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"
VHIDCTL="/usr/local/bin/vhidctl"
REPO_USER="Thecodeisrereall"
REPO_NAME="MacScope"
SCRIPTS_REMOTE="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/main/Scripts"
KIT_DIR="${HOME}/Library/MacScope_vHID_Kit"
VERSION_FILE="${KIT_DIR}/version.txt"
VERSION_LOCAL_CONTENT="v1.0.0 (Karabiner 6.3.0)"
