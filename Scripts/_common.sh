#!/bin/bash
set -euo pipefail
LOG_TAG="[MacScope]"
ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s %s %s\n" "$(ts)" "$LOG_TAG" "$*"; }
warn(){ printf "%s %s [WARN] %s\n" "$(ts)" "$LOG_TAG" "$*" >&2; }
error(){ printf "%s %s [ERROR] %s\n" "$(ts)" "$LOG_TAG" "$*" >&2; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 1; }; }
require_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || { error "Run as root (use sudo)"; exit 1; }; }
KARB_MANAGER="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
KARB_DAEMON="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
SOCKET_DIR="/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"
MACSCOPECTL="/usr/local/bin/macscope-vhid"
KIT_DIR="${HOME}/Library/MacScope_vHID_Kit"
MANIFEST="${KIT_DIR}/manifest.json"
is_running(){ pgrep -fl "$1" >/dev/null 2>&1; }
run_macscopectl(){
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "${MACSCOPECTL}" "$@"
  elif [[ -t 0 ]]; then
    sudo "${MACSCOPECTL}" "$@"
  else
    /usr/bin/osascript -e 'do shell script "/usr/local/bin/macscope-vhid '"$*"'" with administrator privileges'
  fi
}
