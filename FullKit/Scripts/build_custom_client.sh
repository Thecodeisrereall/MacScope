#!/bin/bash
# install_vhidrelay.sh — install vhidrelay binary and LaunchDaemon
set -euo pipefail

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
err(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; }

# Ensure PATH includes standard directories
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

SRC="vhidrelay.sh"
OUT_BIN="/usr/local/bin/vhidrelay"
PLIST_SRC="daemon/com.macscope.vhidrelay.plist"
PLIST_DEST="/Library/LaunchDaemons/com.macscope.vhidrelay.plist"

if [[ ! -f "$SRC" ]]; then
  err "Source file $SRC not found."
  exit 1
fi

if [[ ! -f "$PLIST_SRC" ]]; then
  err "LaunchDaemon plist $PLIST_SRC not found."
  exit 1
fi

# Copy vhidrelay binary
log "Installing vhidrelay binary to $OUT_BIN..."
if ! sudo cp "$SRC" "$OUT_BIN"; then
  err "Failed to copy $SRC to $OUT_BIN"
  exit 1
fi
sudo chmod 755 "$OUT_BIN"
sudo chown root:wheel "$OUT_BIN"

# Copy LaunchDaemon plist
log "Installing LaunchDaemon plist to $PLIST_DEST..."
if ! sudo cp "$PLIST_SRC" "$PLIST_DEST"; then
  err "Failed to copy $PLIST_SRC to $PLIST_DEST"
  exit 1
fi
sudo chmod 644 "$PLIST_DEST"
sudo chown root:wheel "$PLIST_DEST"

# Unload daemon if loaded
if sudo launchctl print system/com.macscope.vhidrelay &>/dev/null; then
  log "Unloading existing LaunchDaemon com.macscope.vhidrelay..."
  sudo launchctl bootout system "$PLIST_DEST" || log "Daemon not loaded or already unloaded."
fi

# Load daemon
log "Loading LaunchDaemon com.macscope.vhidrelay..."
if sudo launchctl bootstrap system "$PLIST_DEST"; then
  sudo launchctl kickstart -k system/com.macscope.vhidrelay
  log "vhidrelay LaunchDaemon loaded and started successfully ✅"
else
  err "Failed to load LaunchDaemon com.macscope.vhidrelay."
  exit 1
fi

log "vhidrelay installation complete."
