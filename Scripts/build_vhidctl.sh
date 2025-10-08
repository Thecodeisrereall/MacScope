#!/bin/bash
# build_vhidctl.sh — build & install vhidctl using Karabiner's tools/make_server_client_pair.sh
# Usage: sudo ~/Library/MacScope_vHID_Kit/build_vhidctl.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

need_cmd git
need_cmd make
need_cmd bash
need_cmd find
need_cmd xattr || true

TMP="${TMPDIR:-/tmp}/macscope_vhid_build_$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"
cd "$TMP"

log "Cloning Karabiner-DriverKit-VirtualHIDDevice…"
git clone --depth 1 --recurse-submodules https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice.git src
cd src
git fetch --tags >/dev/null 2>&1 || true
git checkout -q "v6.3.0" >/dev/null 2>&1 || true

log "Building via tools/make_server_client_pair.sh …"
chmod +x tools/make_server_client_pair.sh
tools/make_server_client_pair.sh

# Find the client binary produced under build/
CLIENT_BIN="$(/usr/bin/find build -type f -perm -111 -name '*virtual*hid*device*service*client*' | head -n1 || true)"
if [[ -z "${CLIENT_BIN}" || ! -f "${CLIENT_BIN}" ]]; then
  error "Could not find the built client binary under build/."
  exit 1
fi
log "Found client: ${CLIENT_BIN}"

require_root
install -m 4755 "${CLIENT_BIN}" /usr/local/bin/vhidctl
chown root:wheel /usr/local/bin/vhidctl
xattr -dr com.apple.quarantine /usr/local/bin/vhidctl 2>/dev/null || true

log "vhidctl installed to /usr/local/bin/vhidctl ✅"

# Smoke tests
if /usr/local/bin/vhidctl --help >/dev/null 2>&1; then
  log "vhidctl --help OK"
fi
if /usr/local/bin/vhidctl ping >/dev/null 2>&1; then
  log "vhidctl ping OK ✅"
else
  warn "vhidctl ping failed (daemon may not be running yet)."
fi
