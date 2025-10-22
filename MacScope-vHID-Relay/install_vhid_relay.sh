#!/bin/bash
set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOG_FILE="/var/log/macscope-vhid-install.log"
exec > >(awk '{ cmd="date +\"[%Y-%m-%d %H:%M:%S]\""; cmd | getline ts; close(cmd); print ts, $0 }' | tee -a "$LOG_FILE") 2>&1

PKG_PATH="$SCRIPT_DIR/Karabiner-DriverKit-VirtualHIDDevice-6.4.0.pkg"
DAEMON_APP="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app"
DRIVER_DIR="/Library/SystemExtensions"
CLIENT_BIN="/usr/local/bin/macscope-vhid"
PLIST_SRC="./com.macscope.vhid.relay.plist"
PLIST_DST="/Library/LaunchDaemons/com.macscope.vhid.relay.plist"

echo "=== MacScope VirtualHID Simple Installer ==="
[[ "$(id -u)" -ne 0 ]] && { echo "[error] Must run as root (sudo required)"; exit 1; }

# --- Step 1: Download and install Karabiner pkg ---
PKG_URL="https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/raw/main/dist/Karabiner-DriverKit-VirtualHIDDevice-6.4.0.pkg"
PKG_TMP="/tmp/Karabiner-DriverKit-VirtualHIDDevice-6.4.0.pkg"
echo "[stage 1] Downloading Karabiner pkg from official repository..."
curl -L -o "$PKG_TMP" "$PKG_URL" || { echo "[error] Failed to download Karabiner pkg"; exit 1; }
echo "[ok] Downloaded pkg to $PKG_TMP"

echo "[stage 2] Installing Karabiner pkg..."
installer -pkg "$PKG_TMP" -target / || { echo "[error] Pkg installation failed"; exit 1; }
echo "[ok] Karabiner pkg installed successfully"

# --- Step 3: Verify components ---
echo "[stage 3] Verifying installed components..."
[[ -d "$DAEMON_APP" ]] || { echo "[error] Daemon app missing: $DAEMON_APP"; exit 1; }
[[ -d "$DRIVER_DIR" ]] || { echo "[error] DriverKit extension directory missing: $DRIVER_DIR"; exit 1; }
echo "[ok] Karabiner components verified"

# --- Step 4: Build MacScopeClient standalone (no Karabiner build scripts) ---
echo "[stage 4] Building MacScopeClient standalone..."

# Locate source and headers
CLIENT_SRC_DIR="/Users/meklows/Documents/GitHub/MacScope/MacScopeClient/virtual-hid-device-service-client"
HEADER_DIR="/Users/meklows/Documents/GitHub/MacScope/Karabiner-DriverKit-VirtualHIDDevice/include"

# Fallback: try bundled location
if [[ ! -d "$CLIENT_SRC_DIR" ]]; then
  CLIENT_SRC_DIR="$(cd "$SCRIPT_DIR/../MacScopeClient/virtual-hid-device-service-client" 2>/dev/null && pwd || echo "")"
fi
if [[ ! -d "$HEADER_DIR" ]]; then
  HEADER_DIR="$(cd "$SCRIPT_DIR/../Karabiner-DriverKit-VirtualHIDDevice/include" 2>/dev/null && pwd || echo "")"
fi

# Validate source exists
if [[ ! -d "$CLIENT_SRC_DIR" || ! -f "$CLIENT_SRC_DIR/src/main.cpp" ]]; then
  echo "[error] MacScopeClient source not found at: $CLIENT_SRC_DIR"
  exit 1
fi
echo "[info] Found source: $CLIENT_SRC_DIR"

# Check for headers, clone if missing
if [[ ! -d "$HEADER_DIR" ]]; then
  echo "[warn] Karabiner headers not found locally, cloning temporarily..."
  TEMP_HEADER_DIR="/tmp/Karabiner-DriverKit-VirtualHIDDevice-headers-$$"
  git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice.git \
    "$TEMP_HEADER_DIR" 2>&1 | grep -v "Receiving objects" || true
  cd "$TEMP_HEADER_DIR"
  git sparse-checkout set include 2>&1 | grep -v "Updating files" || true
  HEADER_DIR="$TEMP_HEADER_DIR/include"
  trap "rm -rf '$TEMP_HEADER_DIR'" EXIT
  echo "[ok] Cloned headers to: $HEADER_DIR"
else
  echo "[info] Using headers: $HEADER_DIR"
fi

# Validate headers
if [[ ! -d "$HEADER_DIR" ]]; then
  echo "[error] Failed to locate Karabiner headers"
  exit 1
fi

# Build with clang++ directly
echo "[info] Compiling with clang++..."
BUILD_DIR="$CLIENT_SRC_DIR/build"
mkdir -p "$BUILD_DIR"

# Compile flags based on project.yml
CXXFLAGS=(
  -std=gnu++2a
  -Wall
  -Werror
  -O2
  -I"$HEADER_DIR"
  -I"$CLIENT_SRC_DIR/include"
  -framework Foundation
  -framework IOKit
  -mmacosx-version-min=13.0
)

# Collect all .cpp files
CPP_FILES=()
while IFS= read -r -d '' file; do
  CPP_FILES+=("$file")
done < <(find "$CLIENT_SRC_DIR/src" -name "*.cpp" -print0)

if [[ ${#CPP_FILES[@]} -eq 0 ]]; then
  echo "[error] No .cpp files found in $CLIENT_SRC_DIR/src"
  exit 1
fi

echo "[info] Compiling ${#CPP_FILES[@]} source file(s)..."
for cpp_file in "${CPP_FILES[@]}"; do
  echo "[info]   - $(basename "$cpp_file")"
done

# Compile
if clang++ "${CXXFLAGS[@]}" "${CPP_FILES[@]}" -o "$BUILD_DIR/macscope-vhid" 2>&1; then
  echo "[ok] Build succeeded"
else
  echo "[error] clang++ compilation failed"
  exit 1
fi

# Install binary
if [[ ! -f "$BUILD_DIR/macscope-vhid" ]]; then
  echo "[error] Binary not found after build: $BUILD_DIR/macscope-vhid"
  exit 1
fi

cp -f "$BUILD_DIR/macscope-vhid" "$CLIENT_BIN"
chmod 755 "$CLIENT_BIN"
chown root:wheel "$CLIENT_BIN"

# Ad-hoc sign
if codesign -s - --force "$CLIENT_BIN" 2>/dev/null; then
  echo "[ok] Binary signed and installed: $CLIENT_BIN"
else
  echo "[warn] Ad-hoc signing failed (may not be required)"
  echo "[ok] Binary installed: $CLIENT_BIN"
fi

# Verify executable
if [[ ! -x "$CLIENT_BIN" ]]; then
  echo "[error] Binary not executable: $CLIENT_BIN"
  exit 1
fi
echo "[ok] Binary ready: $CLIENT_BIN"

# --- Step 5: Install LaunchDaemon plist ---
echo "[stage 5] Installing LaunchDaemon plist..."
if [[ -f "$PLIST_SRC" ]]; then
  cp "$PLIST_SRC" "$PLIST_DST"
  chmod 644 "$PLIST_DST"
  chown root:wheel "$PLIST_DST"
  echo "[ok] LaunchDaemon installed: $PLIST_DST"
elif [[ -f "$SCRIPT_DIR/com.macscope.vhid.relay.plist" ]]; then
  cp "$SCRIPT_DIR/com.macscope.vhid.relay.plist" "$PLIST_DST"
  chmod 644 "$PLIST_DST"
  chown root:wheel "$PLIST_DST"
  echo "[ok] LaunchDaemon installed: $PLIST_DST"
else
  echo "[warn] LaunchDaemon plist not found, skipping"
fi

# --- Step 6: Summary ---
echo "=== Installation complete ==="
echo "[info] Components installed:"
echo "  - Karabiner Daemon:   $DAEMON_APP"
echo "  - DriverKit path:     $DRIVER_DIR"
echo "  - MacScope client:    $CLIENT_BIN"
if [[ -f "$PLIST_DST" ]]; then
  echo "  - LaunchDaemon:       $PLIST_DST"
fi
echo "[info] Log file: $LOG_FILE"
echo ""
echo "Next steps:"
echo "  1. Approve Karabiner system extension in System Settings > Privacy & Security"
echo "  2. Bootstrap LaunchDaemon: sudo launchctl bootstrap system $PLIST_DST"
echo "  3. Verify: sudo launchctl print system/com.macscope.vhid.relay"
