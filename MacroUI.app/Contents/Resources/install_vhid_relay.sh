#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

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

# Step 2: CRITICAL - Verify Karabiner readiness FIRST
echo "[info] Verifying Karabiner VirtualHID is ready..."
KARABINER_READY=0
for i in {1..15}; do
    if systemextensionsctl list 2>/dev/null | grep -q "Karabiner-DriverKit-VirtualHIDDevice.*activated.*enabled"; then
        if pgrep -x "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
            echo "[ok] Karabiner VirtualHID ready after $i attempts (waited $((i*2))s)"
            KARABINER_READY=1
            break
        fi
    fi
    echo "[wait] Karabiner not ready yet (attempt $i/15)..."
    sleep 2
done

if [[ "$KARABINER_READY" -eq 0 ]]; then
    echo "[error] Karabiner VirtualHID driver/daemon not ready after 30 seconds"
    echo "[error]"
    echo "[error] Required: Karabiner-DriverKit-VirtualHIDDevice must be:"
    echo "[error]   1. Installed from: https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases"
    echo "[error]   2. Approved in System Settings > Privacy & Security > System Extensions"
    echo "[error]   3. Driver activated (restart may be required)"
    echo "[error]"
    echo "[error] To verify readiness, run:"
    echo "[error]   systemextensionsctl list | grep Karabiner"
    echo "[error]   pgrep -x Karabiner-VirtualHIDDevice-Daemon"
    echo "[error]"
    exit 1
fi

# Step 3: Prepare directories
echo "[info] Preparing directories..."
mkdir -p "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"
chmod 755 "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"
chown root:wheel "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"
echo "[ok] Directories prepared"

# Step 4: Download manifest
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

# Step 5: Parse manifest
echo "[info] Parsing manifest..."
MANIFEST_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$MANIFEST_FILE" | cut -d'"' -f4)
if [[ -z "$MANIFEST_VERSION" ]]; then
    echo "[error] Failed to parse manifest version"
    exit 1
fi

FILES_JSON=$(grep -o '"files"[[:space:]]*:[[:space:]]*\[[^\]]*\]' "$MANIFEST_FILE" | sed 's/.*\[\(.*\)\].*/\1/' | tr ',' '\n' | tr -d '"' | tr -d ' ')
if [[ -z "$FILES_JSON" ]]; then
    echo "[error] Failed to parse files array from manifest"
    exit 1
fi
echo "[ok] Manifest version: $MANIFEST_VERSION"

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

# Step 7: Stop existing daemon
echo "[info] Stopping existing daemon (if running)..."
launchctl bootout system/"$LABEL" 2>/dev/null || true
sleep 1

# Step 8: Clean stale sockets
echo "[info] Cleaning stale sockets..."
rm -f "$SOCKET_DIR"/vhid_*.sock 2>/dev/null || true
rm -f /tmp/macs_vhid_*.sock 2>/dev/null || true
echo "[ok] Cleaned stale sockets"

# Step 9: Install binary with ad-hoc signing
echo "[info] Installing binary..."
if [[ -f "$TEMP_DIR/macscope-vhid" ]]; then
    cp "$TEMP_DIR/macscope-vhid" "$BIN_DST"
    chmod 755 "$BIN_DST"
    chown root:wheel "$BIN_DST"
    
    # Ad-hoc sign if not already signed
    if ! codesign --verify "$BIN_DST" 2>/dev/null; then
        echo "[info] Applying ad-hoc code signature..."
        codesign -s - -f "$BIN_DST" 2>/dev/null || echo "[warn] Could not ad-hoc sign binary (may not be required)"
    fi
    
    echo "[ok] Installed macscope-vhid binary"
else
    echo "[error] macscope-vhid binary not found in downloaded files"
    exit 1
fi

# Step 10: Install plist
echo "[info] Installing LaunchDaemon plist..."
if [[ -f "$TEMP_DIR/com.macscope.vhid.relay.plist" ]]; then
    cp "$TEMP_DIR/com.macscope.vhid.relay.plist" "$PLIST_DST"
    chmod 644 "$PLIST_DST"
    chown root:wheel "$PLIST_DST"
    echo "[ok] Installed LaunchDaemon plist"
else
    echo "[error] com.macscope.vhid.relay.plist not found in downloaded files"
    exit 1
fi

# Step 11: Verify plist label
echo "[info] Verifying plist configuration..."
if command -v plutil >/dev/null 2>&1; then
    PLIST_LABEL=$(plutil -extract Label raw -o - "$PLIST_DST" 2>/dev/null || echo "")
    if [[ -n "$PLIST_LABEL" && "$PLIST_LABEL" != "$LABEL" ]]; then
        echo "[warn] Plist Label ($PLIST_LABEL) differs from expected ($LABEL)"
    fi
fi

# Step 12: Bootstrap daemon (only after ALL verification passed)
echo "[info] Bootstrapping LaunchDaemon..."
if ! launchctl bootstrap system "$PLIST_DST" 2>&1 | tee -a "$LOG_FILE"; then
    echo "[error] Failed to bootstrap daemon"
    echo "[error] Check: launchctl print system/$LABEL"
    echo "[error] Check: tail /var/log/macscope-vhid.log"
    exit 1
fi
echo "[ok] Daemon bootstrapped"

# Step 13: Verify daemon status
echo "[info] Verifying daemon status..."
sleep 3

if launchctl print system/"$LABEL" >/dev/null 2>&1; then
    echo "[ok] Daemon is registered in launchctl"
    
    # Check daemon startup in log
    if [[ -f /var/log/macscope-vhid.log ]]; then
        sleep 2  # Give daemon time to write initial logs
        
        if tail -10 /var/log/macscope-vhid.log | grep -q "VirtualHID relay listening\|relay listening"; then
            echo "[ok] Daemon started successfully and is listening"
        elif tail -10 /var/log/macscope-vhid.log | grep -q "\[startup\].*waiting for Karabiner"; then
            echo "[info] Daemon is waiting for Karabiner (normal during startup)"
        elif tail -10 /var/log/macscope-vhid.log | grep -q "ERROR"; then
            echo "[error] Daemon encountered errors during startup:"
            tail -5 /var/log/macscope-vhid.log | grep ERROR
            exit 1
        else
            echo "[info] Daemon started, check logs: tail /var/log/macscope-vhid.log"
        fi
    fi
else
    echo "[error] Daemon failed to register with launchctl"
    exit 1
fi

# Step 14: Persist version
echo "[info] Writing version file..."
echo "$MANIFEST_VERSION" > "$VERSION_FILE"
chmod 644 "$VERSION_FILE"
chown root:wheel "$VERSION_FILE"
echo "[ok] Version $MANIFEST_VERSION written to $VERSION_FILE"

# Step 15: Final summary
echo ""
echo "=== Installation Complete ==="
echo "[ok] MacScope VirtualHID relay installed successfully"
echo ""
echo "Installation Summary:"
echo "  Binary:           $BIN_DST"
echo "  LaunchDaemon:     $PLIST_DST"
echo "  Version:          $MANIFEST_VERSION"
echo "  Install Log:      $LOG_FILE"
echo "  Runtime Log:      /var/log/macscope-vhid.log"
echo ""
echo "Verify Installation:"
echo "  sudo launchctl print system/$LABEL | grep state"
echo "  sudo tail -f /var/log/macscope-vhid.log"
echo "  ls -l /tmp/macs_vhid_*.sock"
echo ""
exit 0
