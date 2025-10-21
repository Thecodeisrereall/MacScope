#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log setup
LOG_FILE="/var/log/macscope-vhid-install.log"
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/macscope-vhid-install.$$.log"
chmod 644 "$LOG_FILE" 2>/dev/null || true
exec > >(awk '{ cmd="date +\"[%Y-%m-%d %H:%M:%S]\""; cmd | getline ts; close(cmd); print ts, $0 }' | tee -a "$LOG_FILE") 2>&1
trap 'echo "[error] installer failed at line $LINENO"; exit 1' ERR

# Constants
MANIFEST_URL="https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main/MacScope-vHID-Relay/manifest.json"
BASE_URL="https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main/MacScope-vHID-Relay"
BIN_DST="/usr/local/bin/macscope-vhid"
PLIST_DST="/Library/LaunchDaemons/com.macscope.vhid.relay.plist"
SOCKET_DIR="/var/run/macscope"
VERSION_FILE="/usr/local/lib/macscope/VERSION"
LABEL="com.macscope.vhid.relay"

echo "=== MacScope VirtualHID Relay Installer ==="

# Step 1: Check EUID
if [[ "$(id -u)" != "0" ]]; then
    echo "[error] must run as root (use: sudo $0)"
    exit 1
fi
echo "[ok] Running as root"

# Step 2: Prepare directories
echo "[info] Preparing directories..."
mkdir -p "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"
chmod 755 "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"
chown root:wheel "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"
echo "[ok] Directories prepared"

# Step 3: Download manifest
echo "[info] Downloading manifest..."
TEMP_DIR="$(mktemp -d /tmp/macscope-install.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MANIFEST_FILE="$TEMP_DIR/manifest.json"

if ! curl --fail --location --silent --show-error --connect-timeout 10 --max-time 120 \
    -o "$MANIFEST_FILE" "$MANIFEST_URL"; then
    echo "[error] Failed to download manifest from $MANIFEST_URL"
    exit 1
fi

if [[ ! -s "$MANIFEST_FILE" ]]; then
    echo "[error] Manifest file is empty"
    exit 1
fi
echo "[ok] Manifest downloaded"

# Step 4: Parse manifest using grep/cut (no python3 dependency)
echo "[info] Parsing manifest..."
MANIFEST_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$MANIFEST_FILE" | cut -d'"' -f4)
if [[ -z "$MANIFEST_VERSION" ]]; then
    echo "[error] Failed to parse manifest version"
    exit 1
fi

# Extract files array
FILES_JSON=$(grep -o '"files"[[:space:]]*:[[:space:]]*\[[^\]]*\]' "$MANIFEST_FILE" | sed 's/.*\[\(.*\)\].*/\1/' | tr ',' '\n' | tr -d '"' | tr -d ' ')
if [[ -z "$FILES_JSON" ]]; then
    echo "[error] Failed to parse files array from manifest"
    exit 1
fi
echo "[ok] Manifest version: $MANIFEST_VERSION"

# Step 5: Verify Karabiner VirtualHID readiness BEFORE downloading
echo "[info] Verifying Karabiner VirtualHID readiness..."
KARABINER_READY=0
for i in {1..15}; do
    if systemextensionsctl list 2>/dev/null | grep -q "Karabiner-DriverKit-VirtualHIDDevice.*activated.*enabled"; then
        if pgrep -x "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
            echo "[ok] Karabiner VirtualHID ready after $i attempts"
            KARABINER_READY=1
            break
        fi
    fi
    echo "[info] Waiting for Karabiner VirtualHID ($i/15)..."
    sleep 2
done

if [[ "$KARABINER_READY" -eq 0 ]]; then
    echo "[error] Karabiner VirtualHID driver/daemon not ready after 30 seconds"
    echo "[error] Please ensure Karabiner-DriverKit-VirtualHIDDevice is installed and approved"
    echo "[error] Check System Settings > Privacy & Security > System Extensions"
    exit 1
fi

# Step 6: Download files
echo "[info] Downloading files..."
for filename in $FILES_JSON; do
    echo "[info] Downloading $filename..."
    FILE_URL="${BASE_URL}/${filename}"
    TEMP_FILE="$TEMP_DIR/$filename"
    
    if ! curl --fail --location --silent --show-error --connect-timeout 10 --max-time 120 \
        -o "$TEMP_FILE" "$FILE_URL"; then
        echo "[error] Failed to download $filename from $FILE_URL"
        exit 1
    fi
    
    if [[ ! -s "$TEMP_FILE" ]]; then
        echo "[error] Downloaded file $filename is empty"
        exit 1
    fi
    echo "[ok] Downloaded $filename"
done

# Step 7: Stop existing daemon before updating
echo "[info] Stopping existing daemon (if running)..."
launchctl bootout system/"$LABEL" 2>/dev/null || true
sleep 1

# Step 8: Clean stale sockets
echo "[info] Cleaning stale sockets..."
rm -f "$SOCKET_DIR"/vhid_*.sock 2>/dev/null || true
echo "[ok] Cleaned stale sockets"

# Step 9: Install files
echo "[info] Installing files..."

# Install binary
if [[ -f "$TEMP_DIR/macscope-vhid" ]]; then
    cp "$TEMP_DIR/macscope-vhid" "$BIN_DST"
    chmod 755 "$BIN_DST"
    chown root:wheel "$BIN_DST"
    echo "[ok] Installed macscope-vhid binary"
else
    echo "[error] macscope-vhid binary not found in downloaded files"
    exit 1
fi

# Install plist
if [[ -f "$TEMP_DIR/com.macscope.vhid.relay.plist" ]]; then
    cp "$TEMP_DIR/com.macscope.vhid.relay.plist" "$PLIST_DST"
    chmod 644 "$PLIST_DST"
    chown root:wheel "$PLIST_DST"
    echo "[ok] Installed LaunchDaemon plist"
else
    echo "[error] com.macscope.vhid.relay.plist not found in downloaded files"
    exit 1
fi

# Step 10: Verify plist label matches
echo "[info] Verifying plist configuration..."
if command -v plutil >/dev/null 2>&1; then
    PLIST_LABEL=$(plutil -extract Label raw -o - "$PLIST_DST" 2>/dev/null || echo "")
    if [[ -n "$PLIST_LABEL" && "$PLIST_LABEL" != "$LABEL" ]]; then
        echo "[warn] Plist label ($PLIST_LABEL) differs from expected ($LABEL)"
    fi
fi

# Step 11: Start daemon
echo "[info] Starting daemon..."

# Bootstrap
if ! launchctl bootstrap system "$PLIST_DST" 2>&1 | tee -a "$LOG_FILE"; then
    echo "[error] Failed to bootstrap daemon"
    echo "[error] Check: launchctl print system/$LABEL"
    echo "[error] Check: tail /var/log/macscope-vhid.log"
    exit 1
fi
echo "[ok] Daemon bootstrapped"

# Step 12: Verify daemon status
echo "[info] Verifying daemon status..."
sleep 2

if launchctl print system/"$LABEL" >/dev/null 2>&1; then
    echo "[ok] Daemon is registered in launchctl"
    
    # Check if daemon has started successfully
    if [[ -f /var/log/macscope-vhid.log ]]; then
        if tail -5 /var/log/macscope-vhid.log | grep -q "VirtualHID relay listening"; then
            echo "[ok] Daemon is running and listening"
        elif tail -5 /var/log/macscope-vhid.log | grep -q "Waiting for Karabiner"; then
            echo "[info] Daemon is waiting for VirtualHID driver (this is normal on first boot)"
        else
            echo "[warn] Daemon status unclear, check: tail /var/log/macscope-vhid.log"
        fi
    fi
else
    echo "[error] Daemon failed to register with launchctl"
    exit 1
fi

# Step 13: Persist version
echo "[info] Writing version file..."
echo "$MANIFEST_VERSION" > "$VERSION_FILE"
chmod 644 "$VERSION_FILE"
chown root:wheel "$VERSION_FILE"
echo "[ok] Version $MANIFEST_VERSION written to $VERSION_FILE"

# Step 14: Final verification
echo "[info] Final verification..."
if [[ -x "$BIN_DST" ]] && [[ -f "$PLIST_DST" ]] && launchctl print system/"$LABEL" >/dev/null 2>&1; then
    echo ""
    echo "=== Installation Successful ==="
    echo "[ok] MacScope VirtualHID relay installed successfully"
    echo ""
    echo "Installation details:"
    echo "  Binary:        $BIN_DST"
    echo "  LaunchDaemon:  $PLIST_DST"
    echo "  Version:       $MANIFEST_VERSION"
    echo "  Log file:      $LOG_FILE"
    echo "  Daemon log:    /var/log/macscope-vhid.log"
    echo ""
    echo "Monitor daemon status:"
    echo "  launchctl print system/$LABEL"
    echo "  tail -f /var/log/macscope-vhid.log"
    echo ""
    exit 0
else
    echo "[error] Installation verification failed"
    exit 1
fi
