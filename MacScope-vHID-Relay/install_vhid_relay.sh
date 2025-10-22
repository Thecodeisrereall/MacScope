#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# === MacScope VirtualHID Relay Installer (Strict Sequential Blocking) ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/macscope-vhid-install.log"
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/macscope-vhid-install.$$.log"
chmod 644 "$LOG_FILE" || true

exec > >(awk '{ cmd="date +\"[%Y-%m-%d %H:%M:%S]\""; cmd | getline ts; close(cmd); print ts, $0 }' | tee -a "$LOG_FILE") 2>&1
trap 'echo "[error] Script failed at line $LINENO. Check $LOG_FILE for details." >&2; exit 1' ERR

MANIFEST_URL="https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main/MacScope-vHID-Relay/manifest.json?ts=$(date +%s)"
BASE_URL="https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main/MacScope-vHID-Relay"
BIN_DST="/usr/local/bin/macscope-vhid"
PLIST_DST="/Library/LaunchDaemons/com.macscope.vhid.relay.plist"
SOCKET_DIR="/var/run/macscope"
VERSION_FILE="/usr/local/lib/macscope/VERSION"
LABEL="com.macscope.vhid.relay"

KARABINER_MANAGER="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
KARABINER_DAEMON="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"

echo "=== MacScope VirtualHID Relay Installer ==="
echo "[info] Strict sequential installation with blocking checks"
echo ""

# ============================================================================
# STAGE 1: Fresh sudo authentication
# ============================================================================
echo "[stage 1] Requesting fresh sudo authentication..."
sudo -k
if ! sudo true; then
  echo "[error] Failed to obtain sudo privileges"
  exit 1
fi
echo "[ok] Sudo authenticated"
echo ""

# ============================================================================
# STAGE 2: Activate Karabiner DriverKit extension
# ============================================================================
echo "[stage 2] Activating Karabiner-DriverKit-VirtualHIDDevice..."

if [[ ! -x "$KARABINER_MANAGER" ]]; then
  echo "[error] Karabiner-VirtualHIDDevice-Manager not found at:"
  echo "        $KARABINER_MANAGER"
  echo "[error] Please install Karabiner-DriverKit-VirtualHIDDevice from:"
  echo "        https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases"
  exit 1
fi

echo "[info] Running activation command..."
if ! "$KARABINER_MANAGER" activate 2>&1 | tee -a "$LOG_FILE"; then
  echo "[warn] Activation command returned non-zero, but continuing to check status..."
fi
echo ""

# ============================================================================
# STAGE 3: Wait for driver activation (blocking)
# ============================================================================
echo "[stage 3] Waiting for driver activation [activated enabled]..."
DRIVER_READY=0
for i in {1..15}; do
  echo "[info] Checking driver status (attempt $i/15)..."
  
  if systemextensionsctl list 2>/dev/null | grep -q "Karabiner-DriverKit-VirtualHIDDevice.*activated.*enabled"; then
    echo "[ok] Driver is activated and enabled"
    DRIVER_READY=1
    break
  fi
  
  echo "[wait] Driver not ready yet, retrying in 2 seconds..."
  sleep 2
done

if [[ "$DRIVER_READY" -eq 0 ]]; then
  echo "[error] Driver failed to activate after 30 seconds"
  echo "[error] Current extension status:"
  systemextensionsctl list 2>/dev/null | grep -i karabiner || echo "        (no Karabiner extensions found)"
  echo ""
  echo "[error] Action required:"
  echo "        1. Open System Settings → Privacy & Security"
  echo "        2. Approve 'Karabiner-DriverKit-VirtualHIDDevice' system extension"
  echo "        3. Restart this installer"
  exit 1
fi
echo ""

# ============================================================================
# STAGE 4: Fresh sudo for daemon launch
# ============================================================================
echo "[stage 4] Re-authenticating sudo for daemon launch..."
sudo -k
if ! sudo true; then
  echo "[error] Failed to re-authenticate sudo"
  exit 1
fi
echo "[ok] Sudo re-authenticated"
echo ""

# ============================================================================
# STAGE 5: Launch Karabiner daemon
# ============================================================================
echo "[stage 5] Launching Karabiner-VirtualHIDDevice-Daemon..."

if [[ ! -x "$KARABINER_DAEMON" ]]; then
  echo "[error] Karabiner daemon not found at:"
  echo "        $KARABINER_DAEMON"
  exit 1
fi

# Kill any existing daemon instances first
echo "[info] Stopping any existing daemon instances..."
sudo pkill -9 -x "Karabiner-VirtualHIDDevice-Daemon" 2>/dev/null || true
sleep 1

echo "[info] Starting daemon..."
sudo "$KARABINER_DAEMON" >/dev/null 2>&1 &
DAEMON_PID=$!
echo "[info] Daemon launched with PID: $DAEMON_PID"
echo ""

# ============================================================================
# STAGE 6: Wait for daemon process (blocking)
# ============================================================================
echo "[stage 6] Waiting for daemon process to be running..."
DAEMON_READY=0
for i in {1..15}; do
  echo "[info] Checking daemon process (attempt $i/15)..."
  
  if pgrep -x "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
    RUNNING_PID=$(pgrep -x "Karabiner-VirtualHIDDevice-Daemon")
    echo "[ok] Daemon is running (PID: $RUNNING_PID)"
    DAEMON_READY=1
    break
  fi
  
  echo "[wait] Daemon process not found yet, retrying in 2 seconds..."
  sleep 2
done

if [[ "$DAEMON_READY" -eq 0 ]]; then
  echo "[error] Daemon failed to start after 30 seconds"
  echo "[error] Process check:"
  pgrep -fl Karabiner || echo "        (no Karabiner processes found)"
  exit 1
fi
echo ""

# ============================================================================
# STAGE 7: Prepare directories
# ============================================================================
echo "[stage 7] Preparing installation directories..."
for dir in "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"; do
  mkdir -p "$dir"
  chmod 755 "$dir"
  chown root:wheel "$dir"
done
echo "[ok] Directories ready"
echo ""

# ============================================================================
# STAGE 8: Download manifest and files
# ============================================================================
echo "[stage 8] Fetching manifest and files from GitHub..."
TMP_DIR="$(mktemp -d /tmp/macscope-install.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT
MANIFEST_FILE="$TMP_DIR/manifest.json"

if ! curl --fail --silent --show-error -L -H "Cache-Control: no-cache" -o "$MANIFEST_FILE" "$MANIFEST_URL"; then
  echo "[error] Could not download manifest"
  exit 1
fi
[[ ! -s "$MANIFEST_FILE" ]] && { echo "[error] Manifest is empty"; exit 1; }

MANIFEST_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$MANIFEST_FILE" | cut -d'"' -f4)
FILES_LIST=$(grep -o '"files"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$MANIFEST_FILE" | sed -E 's/.*\[(.*)\].*/\1/' | tr -d '"' | tr ',' '\n' | awk NF)
[[ -z "$MANIFEST_VERSION" || -z "$FILES_LIST" ]] && { echo "[error] Invalid manifest format"; cat "$MANIFEST_FILE"; exit 1; }

echo "[ok] Manifest version: $MANIFEST_VERSION"

echo "[info] Downloading files..."
for f in $FILES_LIST; do
  echo "[info]   - $f"
  curl --fail --silent --show-error -L "$BASE_URL/$f" -o "$TMP_DIR/$f" || { echo "[error] Failed to download $f"; exit 1; }
done
echo "[ok] Files downloaded"
echo ""

# ============================================================================
# STAGE 9: Install binary
# ============================================================================
echo "[stage 9] Installing MacScope VirtualHID relay binary..."
if [[ ! -f "$TMP_DIR/macscope-vhid" ]]; then
  echo "[error] Binary 'macscope-vhid' not found in downloaded files"
  exit 1
fi

cp "$TMP_DIR/macscope-vhid" "$BIN_DST"
chmod 755 "$BIN_DST"
chown root:wheel "$BIN_DST"

# Ad-hoc sign the binary
echo "[info] Applying ad-hoc code signature..."
if codesign -s - --force "$BIN_DST" >/dev/null 2>&1; then
  echo "[ok] Binary signed"
else
  echo "[warn] Ad-hoc signing failed (may not be required)"
fi

echo "[ok] Binary installed: $BIN_DST"
echo ""

# ============================================================================
# STAGE 10: Install LaunchDaemon plist
# ============================================================================
echo "[stage 10] Installing LaunchDaemon plist..."
if [[ ! -f "$TMP_DIR/com.macscope.vhid.relay.plist" ]]; then
  echo "[error] Plist 'com.macscope.vhid.relay.plist' not found in downloaded files"
  exit 1
fi

cp "$TMP_DIR/com.macscope.vhid.relay.plist" "$PLIST_DST"
chmod 644 "$PLIST_DST"
chown root:wheel "$PLIST_DST"

# Validate plist label
PLIST_LABEL=$(plutil -extract Label raw -o - "$PLIST_DST" 2>/dev/null || echo "")
if [[ "$PLIST_LABEL" != "$LABEL" ]]; then
  echo "[error] Plist label mismatch: got '$PLIST_LABEL', expected '$LABEL'"
  exit 1
fi

echo "[ok] LaunchDaemon validated and installed: $PLIST_DST"
echo ""

# ============================================================================
# STAGE 11: Clean stale sockets
# ============================================================================
echo "[stage 11] Cleaning stale socket files..."
rm -f "$SOCKET_DIR"/vhid_*.sock 2>/dev/null || true
rm -f /tmp/macs_vhid_*.sock 2>/dev/null || true
echo "[ok] Socket cleanup complete"
echo ""

# ============================================================================
# STAGE 12: Bootstrap LaunchDaemon
# ============================================================================
echo "[stage 12] Bootstrapping MacScope relay daemon..."

# Stop any existing instance
echo "[info] Stopping existing daemon instance (if any)..."
sudo launchctl bootout system/"$LABEL" >/dev/null 2>&1 || true
sleep 1

# Bootstrap new instance
echo "[info] Bootstrapping daemon..."
if ! sudo launchctl bootstrap system "$PLIST_DST"; then
  echo "[error] launchctl bootstrap failed"
  echo "[error] Attempting to print daemon status:"
  sudo launchctl print system/"$LABEL" 2>&1 || true
  exit 1
fi

echo "[ok] Daemon bootstrapped"
echo ""

# ============================================================================
# STAGE 13: Verify daemon registration (blocking)
# ============================================================================
echo "[stage 13] Verifying daemon registration..."
DAEMON_REGISTERED=0
for i in {1..15}; do
  echo "[info] Checking daemon registration (attempt $i/15)..."
  
  if sudo launchctl print system/"$LABEL" >/dev/null 2>&1; then
    STATE=$(sudo launchctl print system/"$LABEL" 2>/dev/null | grep "state" | awk '{print $3}' || echo "unknown")
    echo "[ok] Daemon registered with launchctl (state: $STATE)"
    DAEMON_REGISTERED=1
    break
  fi
  
  echo "[wait] Daemon not registered yet, retrying in 2 seconds..."
  sleep 2
done

if [[ "$DAEMON_REGISTERED" -eq 0 ]]; then
  echo "[error] Daemon failed to register after 30 seconds"
  exit 1
fi
echo ""

# ============================================================================
# STAGE 14: Record version
# ============================================================================
echo "[stage 14] Recording installation version..."
echo "$MANIFEST_VERSION" > "$VERSION_FILE"
chmod 644 "$VERSION_FILE"
chown root:wheel "$VERSION_FILE"
echo "[ok] Version recorded: $MANIFEST_VERSION"
echo ""

# ============================================================================
# Installation Complete
# ============================================================================
echo "=== Installation Complete ==="
echo ""
echo "Summary:"
echo "  ✓ Karabiner driver activated"
echo "  ✓ Karabiner daemon running"
echo "  ✓ MacScope relay binary installed: $BIN_DST"
echo "  ✓ LaunchDaemon installed: $PLIST_DST"
echo "  ✓ Daemon bootstrapped and registered"
echo "  ✓ Version: $MANIFEST_VERSION"
echo ""
echo "Logs:"
echo "  Install log:  $LOG_FILE"
echo "  Runtime log:  /var/log/macscope-vhid.log"
echo ""
echo "Verify installation:"
echo "  sudo launchctl print system/$LABEL | grep state"
echo "  sudo tail -f /var/log/macscope-vhid.log"
echo "  ls -l /tmp/macs_vhid_*.sock"
echo ""
exit 0
