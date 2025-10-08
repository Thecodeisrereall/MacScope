#!/bin/bash
# logtail.sh — follow VirtualHID daemon logs via unified logging
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

need_cmd log
log "Tailing daemon logs (press Ctrl+C to stop)…"
log stream --style syslog --predicate 'process == "Karabiner-VirtualHIDDevice-Daemon"'
