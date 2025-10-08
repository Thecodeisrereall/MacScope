#!/bin/bash
# repair_perms.sh — fix permissions for macscope-vhidctl
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

if [[ -x "${MACSCOPECTL}" ]]; then
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    sudo chown root:wheel "${MACSCOPECTL}"
    sudo chmod 755 "${MACSCOPECTL}"
  else
    chown root:wheel "${MACSCOPECTL}"
    chmod 755 "${MACSCOPECTL}"
  fi
  log "macscope-vhidctl ownership & mode set (root:wheel, 755)."
else
  warn "macscope-vhidctl not found at ${MACSCOPECTL}"
fi
