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

if [[ -d "${SOCKET_DIR}" ]]; then
  echo "- Socket dir: PRESENT ($SOCKET_DIR)"
else
  echo "- Socket dir: MISSING ($SOCKET_DIR)"
fi

if [[ -x "${VHIDCTL}" ]]; then
  echo "- vhidctl: PRESENT (${VHIDCTL})"
  if "${VHIDCTL}" ping >/dev/null 2>&1; then
    echo "- vhidctl ping: OK"
  else
    echo "- vhidctl ping: FAILED"
  fi
else
  echo "- vhidctl: MISSING (${VHIDCTL})"
fi
