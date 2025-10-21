#!/bin/bash
set -euo pipefail

echo "[MacScope] Rebuilding vHID relay environment..."
RUNTIME_DIR="/var/run/macscope"
RELAY_BIN="/usr/local/bin/macscope-vhid"
PLIST_PATH="/Library/LaunchDaemons/com.macscope.vhid.relay.plist"

# 1. Stop any running relay daemon
echo "[1/5] Stopping existing relay daemon (if any)"
sudo launchctl bootout system "$PLIST_PATH" >/dev/null 2>&1 || true
sudo pkill -9 -x macscope-vhid >/dev/null 2>&1 || true

# 2. Remove stale sockets and logs
echo "[2/5] Cleaning up old sockets and logs"
sudo rm -rf "$RUNTIME_DIR"
sudo mkdir -p "$RUNTIME_DIR"
sudo chmod 755 "$RUNTIME_DIR"
sudo chown root:wheel "$RUNTIME_DIR"

sudo rm -f /var/log/macscope-vhid.log || true
sudo touch /var/log/macscope-vhid.log
sudo chmod 644 /var/log/macscope-vhid.log

# 3. Verify relay binary and plist exist
if [[ ! -f "$RELAY_BIN" ]]; then
  echo "[error] Relay binary missing: $RELAY_BIN"
  echo "Reinstall it via MacScope installer or from GitHub."
  exit 1
fi
if [[ ! -f "$PLIST_PATH" ]]; then
  echo "[error] LaunchDaemon plist missing: $PLIST_PATH"
  echo "Reinstall it via MacScope installer or from GitHub."
  exit 1
fi

# 4. Reload daemon
echo "[4/5] Bootstrapping relay service"
sudo launchctl bootstrap system "$PLIST_PATH" || {
  echo "[warn] Failed to bootstrap service. Attempting manual start..."
  sudo "$RELAY_BIN" &
}

# 5. Verify socket
echo "[5/5] Checking socket status..."
sleep 2
if find "$RUNTIME_DIR" -name 'vhid_*.sock' | grep -q .; then
  echo "[ok] Socket active:"
  find "$RUNTIME_DIR" -name 'vhid_*.sock'
else
  echo "[warn] No socket found. Relay may not have initialized yet."
  echo "Try: sudo launchctl print system/com.macscope.vhid.relay"
fi

echo "[done] vHID environment rebuilt."