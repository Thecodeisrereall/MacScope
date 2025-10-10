#!/bin/bash
set -e

LOGFILE="/var/log/vhidrelay_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "Starting vhidrelay installation..."

SRC_DIR="../Source/cli/macs-vhid"
DAEMON_PLIST="daemon/com.macscope.vhidrelay.plist"
RELAY_TARGET="relay"
MACSCOPE_TARGET="macscope-vhid"
RELAY_INSTALL_PATH="/usr/local/libexec/macscope-vhid-relay"
MACSCOPE_INSTALL_PATH="/usr/local/bin/macscope-vhid"
LAUNCHD_PLIST_DEST="/Library/LaunchDaemons/com.macscope.vhidrelay.plist"

echo "Checking for required tools and source directories..."

if ! command -v make >/dev/null 2>&1; then
  echo "Error: make is not installed or not in PATH."
  exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "Error: Source directory $SRC_DIR does not exist."
  exit 1
fi

echo "Building $RELAY_TARGET..."
make -C "$SRC_DIR" "$RELAY_TARGET" || { echo "Failed to build $RELAY_TARGET"; exit 1; }

echo "Building $MACSCOPE_TARGET..."
make -C "$SRC_DIR" "$MACSCOPE_TARGET" || { echo "Failed to build $MACSCOPE_TARGET"; exit 1; }

echo "Installing $RELAY_TARGET to $RELAY_INSTALL_PATH..."
sudo install -o root -g wheel -m 755 "$SRC_DIR/$RELAY_TARGET" "$RELAY_INSTALL_PATH"

echo "Installing $MACSCOPE_TARGET to $MACSCOPE_INSTALL_PATH..."
sudo install -o root -g wheel -m 755 "$SRC_DIR/$MACSCOPE_TARGET" "$MACSCOPE_INSTALL_PATH"

if [ -f "$DAEMON_PLIST" ]; then
  echo "Found LaunchDaemon plist: $DAEMON_PLIST"
  echo "Copying plist to $LAUNCHD_PLIST_DEST..."
  sudo cp "$DAEMON_PLIST" "$LAUNCHD_PLIST_DEST"
  sudo chown root:wheel "$LAUNCHD_PLIST_DEST"
  sudo chmod 644 "$LAUNCHD_PLIST_DEST"

  echo "Loading LaunchDaemon..."
  sudo launchctl unload "$LAUNCHD_PLIST_DEST" 2>/dev/null || true
  sudo launchctl load "$LAUNCHD_PLIST_DEST"
else
  echo "No LaunchDaemon plist found at $DAEMON_PLIST, skipping daemon installation."
fi

echo "vhidrelay installation completed successfully."
exit 0
