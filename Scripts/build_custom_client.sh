#!/bin/bash
# build_custom_client.sh — compile & install /usr/local/bin/macscope-vhid using pqrs headers
set -euo pipefail

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
err(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; }

command -v git     >/dev/null 2>&1 || { err "git required"; exit 1; }
command -v clang++ >/dev/null 2>&1 || { err "clang++ required (Xcode CLT)"; exit 1; }

ROOT="${HOME}/Library/MacScope_vHID_Kit"
SRC="${ROOT}/Source/macs-vhid/macscope-vhid.cpp"
OUT="/usr/local/bin/macscope-vhid"

# Optional fallback: fetch source from GitHub if missing locally
if [[ ! -f "$SRC" ]]; then
  GH_SRC="curl -L -o macscope-vhid.cpp https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main/Source/cli/macs-vhid/macscope-vhid.cpp"
  log "Client source not found locally; attempting to download from GitHub…"
  mkdir -p "$(dirname "$SRC")"
  if curl -fsSL "$GH_SRC" -o "$SRC"; then
    log "Fetched client source from GitHub."
  else
    err "Client source not found and GitHub fetch failed. Ensure your app copies Source/macs-vhid/macscope-vhid.cpp."
    exit 1
  fi
fi

TMP="${TMPDIR:-/tmp}/macscope_client_build_$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"
cd "$TMP"

log "Cloning headers…"
git clone --depth 1 https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice.git vhid
git clone --depth 1 https://github.com/pqrs-org/cpp-dispatcher.git              dispatcher
git clone --depth 1 https://github.com/pqrs-org/cpp-local_datagram.git          local_datagram
git clone --depth 1 https://github.com/pqrs-org/cpp-hid.git                     hid

# Include paths (each pqrs repo also vendors deps under vendor/vendor/include)
VHID_INC=(-I "vhid/include"            -I "vhid/vendor/vendor/include")
DISP_INC=(-I "dispatcher/include"      -I "dispatcher/vendor/vendor/include")
LDG_INC=(-I "local_datagram/include"   -I "local_datagram/vendor/vendor/include")
HID_INC=(-I "hid/include"              -I "hid/vendor/vendor/include")

log "Compiling macscope-vhid (C++20)…"
clang++ -std=c++20 -O2 -stdlib=libc++ \
  "${VHID_INC[@]}" "${DISP_INC[@]}" "${LDG_INC[@]}" "${HID_INC[@]}" \
  "$SRC" -o macscope-vhid

# Install (root if needed)
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then SUDO=sudo; else SUDO=; fi
$SUDO install -m 755 macscope-vhid "$OUT"
$SUDO chown root:wheel "$OUT" || true
xattr -dr com.apple.quarantine "$OUT" 2>/dev/null || true

log "Installed $OUT ✅"
log "Try: sudo macscope-vhid ping"
