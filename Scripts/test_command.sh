#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
echo "=== MacScope vHID Test ==="
if [[ -x "${KARB_MANAGER}" ]]; then
  log "Activating Manager…"
  "${KARB_MANAGER}" activate || true
fi
if is_running "Karabiner-VirtualHIDDevice-Daemon"; then
  log "Daemon is running."
else
  log "Daemon not running — attempting start."
  require_root
  nohup "${KARB_DAEMON}" >/dev/null 2>&1 &
  sleep 2
fi
# give daemon a moment to create sockets
sleep 1
# try ping
if run_macscopectl ping ; then
  log "macscope-vhid ping OK ✅"
  exit 0
fi
# diagnostics
warn "Ping failed; listing possible socket dirs:"
for d in "${SOCKET_DIR}" "${SOCKET_DIR_FALLBACK}"; do
  if [[ -d "$d" ]]; then
    ls -la "$d" || true
  else
    echo "(missing dir) $d"
  fi
done
error "macscope-vhid ping failed ❌"
exit 2
