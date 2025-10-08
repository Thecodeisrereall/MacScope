#!/bin/bash
# build_vhidctl.sh — build & install vhidctl from examples/virtual-hid-device-service-client
# Per README: brew install xcodegen; make; make run
# Usage: ~/Library/MacScope_vHID_Kit/build_vhidctl.sh   (will prompt for sudo when installing to /usr/local/bin)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

need_cmd git
need_cmd make
need_cmd xcodebuild
command -v xcodegen >/dev/null 2>&1 || warn "xcodegen not found; make will try to install or you can: brew install xcodegen"

TMP="${TMPDIR:-/tmp}/macscope_vhid_build_$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"
cd "$TMP"

log "Cloning Karabiner-DriverKit-VirtualHIDDevice…"
git clone --depth 1 --recurse-submodules https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice.git src
cd src
git fetch --tags >/dev/null 2>&1 || true
# Pin to 6.3.0 if tag exists; ignore errors if not
git checkout -q "v6.3.0" >/dev/null 2>&1 || true

log "Building example client (examples/virtual-hid-device-service-client)…"
cd examples/virtual-hid-device-service-client
make

# Look for the produced binary
BIN="$(/usr/bin/find . -type f -perm -111 -name 'virtual-hid-device-service-client*' | head -n1 || true)"
if [[ -z "${BIN}" || ! -f "${BIN}" ]]; then
  # Try in a typical Xcode build Products location
  BIN="$(/usr/bin/find ../../.. -type f -perm -111 -name 'virtual-hid-device-service-client*' | head -n1 || true)"
fi

if [[ -z "${BIN}" || ! -f "${BIN}" ]]; then
  error "Could not find the built client binary."
  exit 1
fi
log "Found client: ${BIN}"

# Install to /usr/local/bin/vhidctl (no setuid; we will run via sudo)
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO=sudo
else
  SUDO=
fi

$SUDO install -m 755 "${BIN}" /usr/local/bin/vhidctl
$SUDO chown root:wheel /usr/local/bin/vhidctl || true

log "vhidctl installed to /usr/local/bin/vhidctl ✅"

# Smoke tests (may require daemon to be running; ping will use sudo automatically)
if run_vhidctl --help >/dev/null 2>&1; then
  log "vhidctl --help OK"
fi
if run_vhidctl ping >/dev/null 2>&1; then
  log "vhidctl ping OK ✅"
else
  warn "vhidctl ping failed (daemon may not be running yet)."
fi
