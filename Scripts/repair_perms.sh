#!/bin/bash
# repair_perms.sh — fix permissions for scripts and vhidctl
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

log "Repairing permissions…"

# Scripts in user Library
if [[ -d "${KIT_DIR}" ]]; then
  find "${KIT_DIR}" -type f -name "*.sh" -exec chmod 755 {} \;
  log "Scripts chmod 755 under ${KIT_DIR}"
else
  warn "No script kit dir at ${KIT_DIR}"
fi

# vhidctl binary
if [[ -x "${VHIDCTL}" ]]; then
  require_root
  chown root:wheel "${VHIDCTL}"
  chmod 4755 "${VHIDCTL}"
  log "vhidctl ownership and mode repaired."
else
  warn "vhidctl not found at ${VHIDCTL}"
fi

log "Done ✅"
