#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec > >(tee -a /var/log/macscope-vhid-install.log) 2>&1
cd "$SCRIPT_DIR"

# install_vhid_relay.sh
# VirtualHID System Installer for MacScope
# This script installs the Karabiner-DriverKit-VirtualHIDDevice driver and MacScope relay daemon

echo "=== MacScope VirtualHID System Installer ==="
echo "Installing Karabiner VirtualHID driver and relay daemon..."

# Check if running as root (via sudo)
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run with sudo privileges"
   exit 1
fi

# Step 0: Check manifest and prepare directories
echo "Step 0: Checking manifest and preparing directories..."

REPO_BASE="https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main"
MANIFEST_URL="$REPO_BASE/manifest.json"
MANIFEST_PATH="/tmp/macscope_manifest.json"
INSTALL_BASE="/usr/local/macscope"
BIN_DIR="/usr/local/bin"
LAUNCHD_DIR="/Library/LaunchDaemons"
LOG_DIR="/var/log"
RUNTIME_DIR="/var/run/macscope"

mkdir -p "$INSTALL_BASE" "$BIN_DIR" "$LAUNCHD_DIR" "$LOG_DIR" "$RUNTIME_DIR"
chmod 755 "$INSTALL_BASE" "$BIN_DIR" "$LAUNCHD_DIR" "$RUNTIME_DIR"
chown root:wheel "$INSTALL_BASE" "$BIN_DIR" "$LAUNCHD_DIR" "$RUNTIME_DIR" || true

echo "[info] Downloading manifest..."
curl -fsSL "$MANIFEST_URL" -o "$MANIFEST_PATH" || { echo "[error] Failed to download manifest"; exit 1; }

echo "[info] Manifest fetched successfully. (Version check skipped — always reinstalling for now.)"

echo "[info] Downloading and replacing MacScope VirtualHID components..."
curl -fsSL "$REPO_BASE/macscope-vhid" -o "$BIN_DIR/macscope-vhid"
curl -fsSL "$REPO_BASE/com.macscope.vhid.relay.plist" -o "$LAUNCHD_DIR/com.macscope.vhid.relay.plist"

chmod 755 "$BIN_DIR/macscope-vhid" || true
chmod 644 "$LAUNCHD_DIR/com.macscope.vhid.relay.plist" || true
chown root:wheel "$BIN_DIR/macscope-vhid" "$LAUNCHD_DIR/com.macscope.vhid.relay.plist" || true

echo "[ok] Files downloaded and installed in correct locations."

 # Get the real user (not root)
REAL_USER=${SUDO_USER:-$USER}
REAL_UID=${SUDO_UID:-$(id -u $REAL_USER)}

echo "Installing for user: $REAL_USER (UID: $REAL_UID)"

# Step 0.5: Rebuild and refresh directories
echo "Step 0.5: Cleaning stale sockets and rebuilding structure..."
pkill -9 macscope-vhid 2>/dev/null || true
rm -f /var/run/macscope/vhid_*.sock
rm -f /usr/local/bin/macscope-vhid
rm -f /Library/LaunchDaemons/com.macscope.vhid.relay.plist

echo "[info] Rebuilding directories..."
mkdir -p /usr/local/bin /Library/LaunchDaemons /var/run/macscope /var/log
chmod 755 /usr/local/bin /Library/LaunchDaemons /var/run/macscope
chown root:wheel /usr/local/bin /Library/LaunchDaemons /var/run/macscope || true

echo "[info] Downloading fresh components from GitHub..."
REPO_BASE="https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main"
curl -fsSL "$REPO_BASE/macscope-vhid" -o "/usr/local/bin/macscope-vhid"
curl -fsSL "$REPO_BASE/com.macscope.vhid.relay.plist" -o "/Library/LaunchDaemons/com.macscope.vhid.relay.plist"

chmod 755 /usr/local/bin/macscope-vhid || true
chmod 644 /Library/LaunchDaemons/com.macscope.vhid.relay.plist || true
chown root:wheel /usr/local/bin/macscope-vhid /Library/LaunchDaemons/com.macscope.vhid.relay.plist || true

echo "[ok] Components downloaded and directories rebuilt."

# Step 1: Install Karabiner-DriverKit-VirtualHIDDevice
echo "Step 1: Installing Karabiner VirtualHID driver..."

# Download and install the driver package
DRIVER_URL="https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v3.1.0/Karabiner-DriverKit-VirtualHIDDevice-3.1.0.pkg"
TEMP_PKG="/tmp/karabiner-vhid.pkg"

echo "Downloading driver package..."
curl -L "$DRIVER_URL" -o "$TEMP_PKG"

echo "Installing driver package..."
installer -pkg "$TEMP_PKG" -target /

# Clean up
rm -f "$TEMP_PKG"

# Step 2: Create the relay daemon binary
echo "Step 2: Creating relay daemon..."

# Create the relay daemon script
cat > /usr/local/bin/macscope-vhid << 'EOF'
#!/usr/bin/env python3

import socket
import json
import sys
import os
import struct
import time
from pathlib import Path

# HID Usage IDs for common keys
KEY_CODES = {
    'a': 0x04, 'b': 0x05, 'c': 0x06, 'd': 0x07, 'e': 0x08, 'f': 0x09, 'g': 0x0A, 'h': 0x0B,
    'i': 0x0C, 'j': 0x0D, 'k': 0x0E, 'l': 0x0F, 'm': 0x10, 'n': 0x11, 'o': 0x12, 'p': 0x13,
    'q': 0x14, 'r': 0x15, 's': 0x16, 't': 0x17, 'u': 0x18, 'v': 0x19, 'w': 0x1A, 'x': 0x1B,
    'y': 0x1C, 'z': 0x1D, '1': 0x1E, '2': 0x1F, '3': 0x20, '4': 0x21, '5': 0x22, '6': 0x23,
    '7': 0x24, '8': 0x25, '9': 0x26, '0': 0x27, 'enter': 0x28, 'escape': 0x29, 'backspace': 0x2A,
    'tab': 0x2B, 'space': 0x2C, 'leftArrow': 0x50, 'rightArrow': 0x4F, 'upArrow': 0x52, 'downArrow': 0x51
}

MODIFIER_CODES = {
    'leftControl': 0x01, 'leftShift': 0x02, 'leftAlt': 0x04, 'leftCommand': 0x08,
    'rightControl': 0x10, 'rightShift': 0x20, 'rightAlt': 0x40, 'rightCommand': 0x80
}

class VHIDRelay:
    def __init__(self):
        self.keyboard_fd = None
        self.mouse_fd = None
        
    def connect_devices(self):
        """Connect to virtual HID devices"""
        try:
            # Find the virtual keyboard and mouse devices
            device_dir = Path("/dev")
            keyboard_pattern = "Karabiner-DriverKit-VirtualHIDKeyboard"
            mouse_pattern = "Karabiner-DriverKit-VirtualHIDPointing"
            
            keyboard_device = None
            mouse_device = None
            
            for device in device_dir.glob("*"):
                if keyboard_pattern in str(device):
                    keyboard_device = device
                elif mouse_pattern in str(device):
                    mouse_device = device
            
            if not keyboard_device:
                print("ERROR: Virtual keyboard device not found", file=sys.stderr)
                return False
                
            if not mouse_device:
                print("ERROR: Virtual mouse device not found", file=sys.stderr)
                return False
            
            self.keyboard_fd = os.open(str(keyboard_device), os.O_WRONLY)
            self.mouse_fd = os.open(str(mouse_device), os.O_WRONLY)
            
            print(f"Connected to keyboard: {keyboard_device}")
            print(f"Connected to mouse: {mouse_device}")
            return True
            
        except Exception as e:
            print(f"ERROR: Failed to connect to HID devices: {e}", file=sys.stderr)
            return False
    
    def send_key(self, key_code, modifiers=0):
        """Send a key press and release"""
        if not self.keyboard_fd:
            return False
            
        try:
            # Key press
            report = struct.pack('BBBBBBBB', modifiers, 0, key_code, 0, 0, 0, 0, 0)
            os.write(self.keyboard_fd, report)
            
            # Small delay
            time.sleep(0.01)
            
            # Key release
            report = struct.pack('BBBBBBBB', 0, 0, 0, 0, 0, 0, 0, 0)
            os.write(self.keyboard_fd, report)
            
            return True
        except Exception as e:
            print(f"ERROR: Failed to send key: {e}", file=sys.stderr)
            return False
    
    def send_mouse(self, buttons=0, dx=0, dy=0, scroll_x=0, scroll_y=0):
        """Send mouse input"""
        if not self.mouse_fd:
            return False
            
        try:
            # Mouse report: buttons, dx, dy, scroll_y, scroll_x
            report = struct.pack('Bbbbb', buttons, dx, dy, scroll_y, scroll_x)
            os.write(self.mouse_fd, report)
            return True
        except Exception as e:
            print(f"ERROR: Failed to send mouse: {e}", file=sys.stderr)
            return False
    
    def handle_command(self, cmd):
        """Handle a command from the client"""
        try:
            action = cmd.get('action')
            
            if action == 'ping':
                return {'status': 'success', 'message': 'pong'}
                
            elif action == 'key':
                key = cmd.get('key', '').lower()
                modifiers_list = cmd.get('modifiers', [])
                
                key_code = KEY_CODES.get(key)
                if key_code is None:
                    return {'status': 'error', 'message': f'Unknown key: {key}'}
                
                modifiers = 0
                for mod in modifiers_list:
                    mod_code = MODIFIER_CODES.get(mod, 0)
                    modifiers |= mod_code
                
                success = self.send_key(key_code, modifiers)
                return {'status': 'success' if success else 'error'}
                
            elif action == 'type':
                text = cmd.get('text', '')
                delay_ns = cmd.get('delayBetweenKeysNanos', 50_000_000)  # 50ms default
                delay_s = delay_ns / 1_000_000_000
                
                for char in text:
                    if char.lower() in KEY_CODES:
                        key_code = KEY_CODES[char.lower()]
                        # Handle shift for uppercase
                        modifiers = MODIFIER_CODES['leftShift'] if char.isupper() else 0
                        self.send_key(key_code, modifiers)
                        if delay_s > 0:
                            time.sleep(delay_s)
                
                return {'status': 'success'}
                
            elif action == 'mouse_move':
                dx = cmd.get('dx', 0)
                dy = cmd.get('dy', 0)
                success = self.send_mouse(dx=dx, dy=dy)
                return {'status': 'success' if success else 'error'}
                
            elif action == 'mouse_click':
                button = cmd.get('button', 'left')
                button_code = 1 if button == 'left' else 2 if button == 'right' else 0
                
                # Click (press + release)
                self.send_mouse(buttons=button_code)
                time.sleep(0.01)
                self.send_mouse(buttons=0)
                
                return {'status': 'success'}
                
            elif action == 'mouse_scroll':
                dx = cmd.get('dx', 0)
                dy = cmd.get('dy', 0)
                success = self.send_mouse(scroll_x=dx, scroll_y=dy)
                return {'status': 'success' if success else 'error'}
                
            else:
                return {'status': 'error', 'message': f'Unknown action: {action}'}
                
        except Exception as e:
            return {'status': 'error', 'message': str(e)}
    
    def run(self):
        """Main server loop"""
        if not self.connect_devices():
            sys.exit(1)
            
        # Get UID from environment or current user
        uid = os.getenv('SUDO_UID', str(os.getuid()))
        socket_path = f"/var/run/macscope/vhid_{uid}.sock"
        
        # Remove existing socket
        try:
            os.unlink(socket_path)
        except FileNotFoundError:
            pass
        
        # Create Unix socket
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind(socket_path)
        sock.listen(1)
        
        # Make socket accessible to the user
        os.chown(socket_path, int(uid), int(uid))
        os.chmod(socket_path, 0o666)
        
        print(f"VirtualHID relay listening on {socket_path}")
        
        try:
            while True:
                conn, addr = sock.accept()
                print("Client connected")
                
                try:
                    while True:
                        data = conn.recv(4096)
                        if not data:
                            break
                            
                        try:
                            cmd = json.loads(data.decode())
                            response = self.handle_command(cmd)
                            conn.send(json.dumps(response).encode() + b'\n')
                        except json.JSONDecodeError:
                            error_response = {'status': 'error', 'message': 'Invalid JSON'}
                            conn.send(json.dumps(error_response).encode() + b'\n')
                            
                except ConnectionResetError:
                    print("Client disconnected")
                finally:
                    conn.close()
                    
        except KeyboardInterrupt:
            print("Shutting down...")
        finally:
            sock.close()
            try:
                os.unlink(socket_path)
            except:
                pass

if __name__ == "__main__":
    relay = VHIDRelay()
    relay.run()
EOF

# Make the daemon executable
chmod +x /usr/local/bin/macscope-vhid

 # Step 3: Create the launchd plist
echo "Step 3: Creating launch daemon..."

# Only ensure log files exist, directory creation was already handled above
touch /var/log/macscope-vhid.log /var/log/macscope-vhid.error.log
chmod 644 /var/log/macscope-vhid*.log
chown root:wheel /var/log || true

cat > /Library/LaunchDaemons/com.macscope.vhid.relay.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.macscope.vhid.relay</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/macscope-vhid</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>SUDO_UID</key>
        <string>$REAL_UID</string>
    </dict>
    <key>StandardOutPath</key>
    <string>/var/log/macscope-vhid.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/macscope-vhid.error.log</string>
</dict>
</plist>
EOF

# Set proper permissions
chown root:wheel /Library/LaunchDaemons/com.macscope.vhid.relay.plist
chmod 644 /Library/LaunchDaemons/com.macscope.vhid.relay.plist

# Cleanup stale sockets and clients
# Already handled in Step 0.5 above

# Step 4: Load the daemon
echo "Step 4: Starting relay daemon..."

echo "[info] Fixing permissions for relay binary and plist..."
chmod 755 /usr/local/bin/macscope-vhid || true
chown root:wheel /usr/local/bin/macscope-vhid || true
chmod 644 /Library/LaunchDaemons/com.macscope.vhid.relay.plist || true
chown root:wheel /Library/LaunchDaemons/com.macscope.vhid.relay.plist || true
sync
sleep 1

echo "[info] Attempting to bootstrap LaunchDaemon..."
if ! launchctl bootstrap system /Library/LaunchDaemons/com.macscope.vhid.relay.plist 2>>/var/log/macscope-vhid.error.log; then
    echo "[error] LaunchDaemon bootstrap failed (I/O error or missing file)" | tee -a /var/log/macscope-vhid.error.log
    echo "[debug] Checking file paths and permissions..." | tee -a /var/log/macscope-vhid.error.log
    ls -l /usr/local/bin/macscope-vhid /Library/LaunchDaemons/com.macscope.vhid.relay.plist >> /var/log/macscope-vhid.error.log 2>&1
    echo "[suggestion] Ensure both files exist and are owned by root:wheel" | tee -a /var/log/macscope-vhid.error.log
    exit 5
fi
echo "[ok] LaunchDaemon bootstrapped successfully."

# Wait a moment for the daemon to start
sleep 2

# Step 5: Verify installation
echo "Step 5: Verifying installation..."

# Check if driver is loaded
if systemextensionsctl list | grep -q "Karabiner-DriverKit-VirtualHIDDevice.*activated enabled"; then
    echo "✓ Karabiner VirtualHID driver is loaded and activated"
else
    echo "⚠ Karabiner VirtualHID driver may not be fully activated yet"
    echo "  You may need to approve the system extension in System Settings > Privacy & Security"
fi

# Check if daemon is running
if launchctl list | grep -q "com.macscope.vhid.relay"; then
    echo "✓ MacScope VirtualHID relay daemon is running"
else
    echo "✗ MacScope VirtualHID relay daemon failed to start"
fi

# Check if socket exists
SOCKET_PATH="/var/run/macscope/vhid_${REAL_UID}.sock"
if [[ -S "$SOCKET_PATH" ]]; then
    echo "✓ Unix socket created at $SOCKET_PATH"
else
    echo "⚠ Unix socket not found (daemon may still be starting)"
fi

echo ""
echo "=== Installation Complete ==="
echo "The VirtualHID system has been installed."
echo ""
echo "If you see warnings about the system extension not being activated,"
echo "please go to System Settings > Privacy & Security and approve the"
echo "Karabiner-DriverKit-VirtualHIDDevice system extension."
echo ""
echo "You can now test the system from the MacScope VirtualHID Manager."

# Final permissions and ownership verification/fix
echo "[final] Ensuring permissions on all MacScope directories and files..."
chmod 755 /usr/local/bin /usr/local/bin/macscope-vhid 2>/dev/null || true
chmod 755 /var/run/macscope 2>/dev/null || true
chmod 644 /Library/LaunchDaemons/com.macscope.vhid.relay.plist 2>/dev/null || true
chmod 644 /var/log/macscope-vhid*.log 2>/dev/null || true
chown root:wheel /usr/local/bin/macscope-vhid /Library/LaunchDaemons/com.macscope.vhid.relay.plist /var/run/macscope 2>/dev/null || true
echo "[ok] Permissions fixed."
