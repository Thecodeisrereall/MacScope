#!/bin/bash
# repair_perms.sh — fix permissions for vhidctl
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

if [[ -x "${VHIDCTL}" ]]; then
  require_root
  chown root:wheel "${VHIDCTL}"
  chmod 4755 "${VHIDCTL}"
  log "vhidctl ownership & mode repaired (root:wheel, 4755)."
else
  warn "vhidctl not found at ${VHIDCTL}"
fi
