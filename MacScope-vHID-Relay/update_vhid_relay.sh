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
trap 'echo "[error] updater failed at line $LINENO"; exit 1' ERR

# Constants
MANIFEST_URL="https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main/MacScope-vHID-Relay/manifest.json"
BASE_URL="https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main/MacScope-vHID-Relay"
BIN_DST="/usr/local/bin/macscope-vhid"
PLIST_DST="/Library/LaunchDaemons/com.macscope.vhid.relay.plist"
SOCKET_DIR="/var/run/macscope"
VERSION_FILE="/usr/local/lib/macscope/VERSION"
LABEL="com.macscope.vhid.relay"

echo "=== MacScope VirtualHID Relay Updater ==="

# Step 1: Check EUID
if [[ "$(id -u)" != "0" ]]; then
    echo "[error] must run as root (use: sudo $0)"
    exit 1
fi
echo "[ok] Running as root"

# Step 2: Check installed version
INSTALLED_VERSION=""
if [[ -f "$VERSION_FILE" ]]; then
    INSTALLED_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
    echo "[info] Installed version: $INSTALLED_VERSION"
else
    echo "[info] No version file found, will perform fresh install"
fi

# Step 3: Download manifest to check latest version
echo "[info] Checking for updates..."
TEMP_DIR="$(mktemp -d /tmp/macscope-update.XXXXXX)"
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

# Parse manifest using grep/cut
MANIFEST_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$MANIFEST_FILE" | cut -d'"' -f4)
if [[ -z "$MANIFEST_VERSION" ]]; then
    echo "[error] Failed to parse manifest version"
    exit 1
fi
echo "[info] Latest version: $MANIFEST_VERSION"

# Step 4: Compare versions
if [[ "$INSTALLED_VERSION" == "$MANIFEST_VERSION" ]]; then
    echo "[info] Already up-to-date (version $INSTALLED_VERSION)"
    exit 0
fi

echo "[info] Update available: $INSTALLED_VERSION -> $MANIFEST_VERSION"
echo "[info] Proceeding with update..."

# Step 5: Prepare directories
mkdir -p "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"
chmod 755 "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"
chown root:wheel "$(dirname "$BIN_DST")" "$(dirname "$PLIST_DST")" "$SOCKET_DIR" "$(dirname "$VERSION_FILE")"

# Step 6: Parse and download files
FILES_JSON=$(grep -o '"files"[[:space:]]*:[[:space:]]*\[[^\]]*\]' "$MANIFEST_FILE" | sed 's/.*\[\(.*\)\].*/\1/' | tr ',' '\n' | tr -d '"' | tr -d ' ')
if [[ -z "$FILES_JSON" ]]; then
    echo "[error] Failed to parse files array from manifest"
    exit 1
fi

echo "[info] Downloading update files..."
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

# Step 7: Stop daemon before updating
echo "[info] Stopping daemon..."
launchctl bootout system/"$LABEL" 2>/dev/null || true
sleep 2

# Step 8: Clean stale sockets
rm -f "$SOCKET_DIR"/vhid_*.sock 2>/dev/null || true

# Step 9: Install updated files
echo "[info] Installing updated files..."

# Install binary
if [[ -f "$TEMP_DIR/macscope-vhid" ]]; then
    cp "$TEMP_DIR/macscope-vhid" "$BIN_DST"
    chmod 755 "$BIN_DST"
    chown root:wheel "$BIN_DST"
    echo "[ok] Updated macscope-vhid binary"
else
    echo "[error] macscope-vhid binary not found in downloaded files"
    exit 1
fi

# Install plist
if [[ -f "$TEMP_DIR/com.macscope.vhid.relay.plist" ]]; then
    cp "$TEMP_DIR/com.macscope.vhid.relay.plist" "$PLIST_DST"
    chmod 644 "$PLIST_DST"
    chown root:wheel "$PLIST_DST"
    echo "[ok] Updated LaunchDaemon plist"
else
    echo "[error] com.macscope.vhid.relay.plist not found in downloaded files"
    exit 1
fi

# Step 10: Start updated daemon
echo "[info] Starting updated daemon..."
if ! launchctl bootstrap system "$PLIST_DST" 2>&1 | tee -a "$LOG_FILE"; then
    echo "[error] Failed to bootstrap updated daemon"
    exit 1
fi
echo "[ok] Daemon started"

# Step 11: Verify daemon status
sleep 2
if launchctl print system/"$LABEL" >/dev/null 2>&1; then
    echo "[ok] Updated daemon is running"
else
    echo "[error] Updated daemon failed to start"
    exit 1
fi

# Step 12: Update version file
echo "$MANIFEST_VERSION" > "$VERSION_FILE"
chmod 644 "$VERSION_FILE"
chown root:wheel "$VERSION_FILE"

echo ""
echo "=== Update Successful ==="
echo "[ok] MacScope VirtualHID relay updated successfully to version $MANIFEST_VERSION"
echo ""
echo "Monitor daemon:"
echo "  launchctl print system/$LABEL"
echo "  tail -f /var/log/macscope-vhid.log"
echo ""
exit 0
