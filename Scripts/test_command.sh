#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "${SCRIPT_DIR}/_common.sh"
echo "=== MacScope vHID Test ==="
if [[ -x "${KARB_MANAGER}" ]]; then log "Activating Manager…"; "${KARB_MANAGER}" activate || true; else warn "Manager app missing: ${KARB_MANAGER}"; fi
if is_running "Karabiner-VirtualHIDDevice-Daemon"; then log "Daemon is running."; else require_root; log "Daemon not running — attempting start."; nohup "${KARB_DAEMON}" >/dev/null 2>&1 &; sleep 1; fi
is_running "Karabiner-VirtualHIDDevice-Daemon" || { error "Daemon failed to start"; exit 1; }
if run_macscopectl ping ; then log "macscope-vhid ping OK ✅"; exit 0; else error "macscope-vhid ping failed ❌"; exit 2; fi
