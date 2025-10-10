#!/usr/bin/env bash
# vhidrelay.sh — Minimal vHID relay
# Ensures daemon is active and vhidctl responds.

set -euo pipefail

mkdir -p /var/log/macscope-vhid
chmod 755 /var/log/macscope-vhid

PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

LOG_DIR="/var/log/macscope-vhid"
LOG_FILE="$LOG_DIR/relay.log"

DAEMON="Karabiner-VirtualHIDDevice-Daemon"
VHIDCTL="/usr/local/bin/vhidctl"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

log() {
  local msg="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [relay] $msg" | tee -a "$LOG_FILE"
}

error_exit() {
  local msg="$1"
  log "ERROR: $msg"
  log "Relay finished with FAILURE."
  exit 1
}

log "Starting vHID relay check..."

if [[ $EUID -ne 0 ]]; then
  log "WARNING: Script is not running as root."
fi

# Check required commands
for cmd in pgrep launchctl "$VHIDCTL"; do
  if ! command -v "$(basename "$cmd")" >/dev/null 2>&1 && [[ ! -x "$cmd" ]]; then
    error_exit "Required tool '$cmd' not found or not executable."
  fi
done

log "Checking vHID daemon..."
if ! pgrep -fq "$DAEMON"; then
  log "Daemon not running, starting..."
  if ! launchctl kickstart -kp system/org.pqrs.Karabiner-DriverKit-VirtualHIDDevice 2>/dev/null; then
    error_exit "Failed to kickstart daemon."
  fi
  log "Daemon started successfully."
else
  log "Daemon already running."
fi

if [[ -x "$VHIDCTL" ]]; then
  log "Pinging vhidctl..."
  if "$VHIDCTL" ping; then
    log "vhidctl ping succeeded."
  else
    error_exit "vhidctl ping failed."
  fi
else
  error_exit "vhidctl executable missing at $VHIDCTL."
fi

log "Relay finished with SUCCESS."
