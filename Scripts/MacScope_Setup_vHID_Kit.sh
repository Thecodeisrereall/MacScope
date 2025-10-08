#!/bin/bash
# MacScope_Setup_vHID_Kit.sh — bootstrap user scripts into ~/Library/MacScope_vHID_Kit
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

log "Bootstrapping scripts into ${KIT_DIR}"

need_cmd curl

mkdir -p "${KIT_DIR}"
chmod 755 "${KIT_DIR}"

FILES=(
  "_common.sh"
  "build_vhidctl.sh"
  "ensure_daemon.sh"
  "repair_perms.sh"
  "restart.sh"
  "status.sh"
  "logtail.sh"
  "version.txt"
)

# If running from a local Scripts/ checkout, copy from here; otherwise fetch from GitHub.
for f in "${FILES[@]}"; do
  if [[ -f "${SCRIPT_DIR}/${f}" ]]; then
    cp -f "${SCRIPT_DIR}/${f}" "${KIT_DIR}/${f}"
  else
    log "Downloading ${f}"
    curl -fsSL "${SCRIPTS_REMOTE}/${f}" -o "${KIT_DIR}/${f}"
  fi
done

# Ensure executability on .sh files
find "${KIT_DIR}" -maxdepth 1 -type f -name "*.sh" -exec chmod 755 {} \;

# Write/refresh version
echo "${VERSION_LOCAL_CONTENT}" > "${VERSION_FILE}"

log "Installed scripts at ${KIT_DIR} ✅"
log "You can now run: ${KIT_DIR}/status.sh"
