#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "${SCRIPT_DIR}/_common.sh"
require_root
log "Stopping daemon…"; pkill -f "Karabiner-VirtualHIDDevice-Daemon" || true; sleep 1
log "Starting daemon…"; nohup "${KARB_DAEMON}" >/dev/null 2>&1 &; sleep 1
if is_running "Karabiner-VirtualHIDDevice-Daemon"; then log "Daemon restarted ✅"; else error "Failed to restart daemon"; exit 1; fi
