#!/bin/bash
# repair_perms.sh — fix permissions for vhidctl
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

if [[ -x "${VHIDCTL}" ]]; then
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    sudo chown root:wheel "${VHIDCTL}"
    sudo chmod 755 "${VHIDCTL}"
  else
    chown root:wheel "${VHIDCTL}"
    chmod 755 "${VHIDCTL}"
  fi
  log "vhidctl ownership & mode set (root:wheel, 755)."
else
  warn "vhidctl not found at ${VHIDCTL}"
fi
