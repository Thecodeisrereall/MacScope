#!/bin/bash
# test_command.sh — End-to-end diagnostic (manager, daemon, vhidctl ping)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

echo "=== MacScope vHID Test ==="

# 1) Manager
if [[ -x "${KARB_MANAGER}" ]]; then
  log "Activating Manager…"
  "${KARB_MANAGER}" activate || true
else
  warn "Manager app missing: ${KARB_MANAGER}"
fi

# 2) Daemon
if is_running "Karabiner-VirtualHIDDevice-Daemon"; then
  log "Daemon is running."
else
  log "Daemon not running — attempting start."
  require_root
  nohup "${KARB_DAEMON}" >/dev/null 2>&1 &
  sleep 1
fi

is_running "Karabiner-VirtualHIDDevice-Daemon" || { error "Daemon failed to start"; exit 1; }

# 3) Socket dir
if [[ -d "${SOCKET_DIR}" ]]; then
  log "Socket directory present."
else
  warn "Socket directory missing (may appear after first client ping)."
fi

# 4) vhidctl ping
if [[ -x "${VHIDCTL}" ]]; then
  if "${VHIDCTL}" ping ; then
    log "vhidctl ping OK ✅"
    exit 0
  else
    error "vhidctl ping failed ❌"
    exit 2
  fi
else
  error "vhidctl not found at ${VHIDCTL} — run build_vhidctl.sh"
  exit 3
fi
