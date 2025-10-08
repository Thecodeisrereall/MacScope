#!/bin/bash
# build_vhidctl.sh — build and install the vhidctl helper
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

log "Building vhidctl (Karabiner 6.3.0)…"
need_cmd git
need_cmd clang++

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

git clone --depth 1 --recurse-submodules https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice.git src
# Optionally lock to tag
# (cd src && git fetch --tags && git checkout v6.3.0) || true

cd src/examples/virtual-hid-device-service-client

SRC="main.cpp"
[[ -f "$SRC" ]] || { error "Cannot find $SRC"; exit 1; }

clang++ -std=c++17 -O2 "$SRC" \
  -I ../../include \
  -I ../../third_party/type_safe/include \
  -I ../../third_party/fmt/include \
  -I ../../third_party/nlohmann_json/include \
  -framework Foundation \
  -o vhidctl

log "Installing vhidctl to /usr/local/bin (root)"
require_root
install -m 4755 vhidctl /usr/local/bin/vhidctl
chown root:wheel /usr/local/bin/vhidctl
xattr -dr com.apple.quarantine /usr/local/bin/vhidctl 2>/dev/null || true

log "Testing vhidctl ping…"
/usr/local/bin/vhidctl ping || warn "vhidctl ping returned non-zero. Ensure daemon is running."
log "vhidctl installed ✅"
