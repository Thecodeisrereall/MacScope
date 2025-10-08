#!/bin/bash
# ensure_daemon.sh — activate manager and ensure daemon is running
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

log "Ensuring Karabiner Manager & Daemon…"

[[ -x "${KARB_MANAGER}" ]] || { error "Manager not found at ${KARB_MANAGER}"; exit 1; }
[[ -x "${KARB_DAEMON}"  ]] || { error "Daemon not found at ${KARB_DAEMON}"; exit 1; }

log "Activating DriverKit via Manager…"
"${KARB_MANAGER}" activate || true

if pgrep -fq "Karabiner-VirtualHIDDevice-Daemon" ; then
  log "Daemon already running."
else
  log "Starting daemon (root)…"
  require_root
  nohup "${KARB_DAEMON}" >/dev/null 2>&1 &
  sleep 1
fi

pgrep -fl "Karabiner-VirtualHIDDevice-Daemon" >/dev/null || { error "Daemon failed to start"; exit 1; }

if [[ -d "${SOCKET_DIR}" ]]; then
  log "Socket dir present: ${SOCKET_DIR}"
else
  warn "Socket dir not present yet: ${SOCKET_DIR} (may appear after first client use)."
fi

log "Done ✅"
