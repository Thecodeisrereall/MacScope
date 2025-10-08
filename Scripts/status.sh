#!/bin/bash
# status.sh — Report vHID environment status
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

echo "=== MacScope vHID Status ==="
echo "- Manager: ${KARB_MANAGER} $([[ -x "${KARB_MANAGER}" ]] && echo 'OK' || echo 'MISSING')"
echo "- Daemon : ${KARB_DAEMON}  $([[ -x "${KARB_DAEMON}"  ]] && echo 'OK' || echo 'MISSING')"

if is_running "Karabiner-VirtualHIDDevice-Daemon"; then
  echo "- Daemon process: RUNNING"
else
  echo "- Daemon process: NOT RUNNING"
fi

if [[ -x "${MACSCOPECTL}" ]]; then
  echo "- macscope-vhidctl: PRESENT (${MACSCOPECTL})"
  if run_macscopectl ping >/dev/null 2>&1; then
    echo "- macscope-vhidctl ping: OK"
  else
    echo "- macscope-vhidctl ping: FAILED"
  fi
else
  echo "- macscope-vhidctl: MISSING (${MACSCOPECTL})"
fi
