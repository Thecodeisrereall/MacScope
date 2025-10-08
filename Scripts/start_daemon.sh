#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "${SCRIPT_DIR}/_common.sh"
[[ -x "${KARB_DAEMON}" ]] || { error "Daemon not found at ${KARB_DAEMON}"; exit 1; }
if is_running "Karabiner-VirtualHIDDevice-Daemon"; then log "Daemon already running."; else require_root; log "Starting daemon (root)…"; nohup "${KARB_DAEMON}" >/dev/null 2>&1 &; sleep 1; fi
if is_running "Karabiner-VirtualHIDDevice-Daemon"; then log "Daemon running ✅"; else error "Daemon failed to start"; exit 1; fi
