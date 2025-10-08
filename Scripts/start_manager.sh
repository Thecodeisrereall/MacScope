#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

[[ -x "${KARB_MANAGER}" ]] || { error "Manager not found at ${KARB_MANAGER}"; exit 1; }

log "Activating DriverKit via Manager…"
"${KARB_MANAGER}" activate || true
log "Manager activation requested ✅"
