#!/usr/bin/env bash
# vhidrelay.sh — Minimal vHID relay
# Ensures daemon is active and vhidctl responds.

set -euo pipefail

DAEMON="Karabiner-VirtualHIDDevice-Daemon"
VHIDCTL="/usr/local/bin/vhidctl"

echo "[relay] Checking vHID daemon..."
if ! pgrep -fq "$DAEMON"; then
  echo "[relay] Daemon not running, starting..."
  launchctl bootstrap system /Library/LaunchDaemons/org.local.vhid.daemon.plist 2>/dev/null || true
  launchctl kickstart -kp system/org.local.vhid.daemon 2>/dev/null || true
else
  echo "[relay] Daemon already running."
fi

if [[ -x "$VHIDCTL" ]]; then
  echo "[relay] Pinging vhidctl..."
  "$VHIDCTL" ping || echo "[relay] vhidctl ping failed."
else
  echo "[relay] vhidctl missing."
fi