#!/bin/bash
# start_daemon.sh — Ensure Karabiner VirtualHID Daemon is running
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

[[ -x "${KARB_DAEMON}" ]] || { error "Daemon not found at ${KARB_DAEMON}"; exit 1; }

if is_running "Karabiner-VirtualHIDDevice-Daemon"; then
  log "Daemon already running."
else
  log "Starting daemon (root)…"
  require_root
  nohup "${KARB_DAEMON}" >/dev/null 2>&1 &
  sleep 1
fi

if is_running "Karabiner-VirtualHIDDevice-Daemon"; then
  log "Daemon running ✅"
else
  error "Daemon failed to start"; exit 1
fi

if [[ -d "${SOCKET_DIR}" ]]; then
  log "Socket dir present: ${SOCKET_DIR}"
else
  warn "Socket dir not present yet: ${SOCKET_DIR} (will appear after first client connection)."
fi
