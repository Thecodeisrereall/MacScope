# MacScope VirtualHID - Quick Start Guide

Get up and running in 5 minutes!

## 📦 What You'll Need

- macOS 13.0+ 
- Your compiled `macscope-vhid` binary
- Administrator (sudo) access
- 5 minutes

---

## 🚀 Option 1: Quick Install (Recommended for Users)

If someone sent you the installer package:

```bash
# Install the package
sudo installer -pkg MacScope_VirtualHID_Installer.pkg -target /

# Approve extension in System Settings if prompted
# Restart Mac if first-time install
```

Done! The daemon is now running.

---

## 🛠️ Option 2: Script Install (For Developers)

If you have the repository:

```bash
# Clone the repo
cd ~/Documents/github
git clone https://github.com/yourusername/macscope-install.git macscope
cd macscope

# Copy your binary
cp /path/to/your/macscope-vhid ./payload/

# Run installer
sudo ./scripts/install_vhid_relay.sh
```

---

## 📦 Option 3: Build Your Own Package

If you want to distribute to others:

```bash
# 1. Copy your binary
cp /path/to/macscope-vhid ./payload/

# 2. Build package
cd build
./build.sh

# 3. Install (creates ~/Desktop/MacScope_VirtualHID_Installer.pkg)
sudo installer -pkg ~/Desktop/MacScope_VirtualHID_Installer.pkg -target /
```

---

## ✅ Verify Installation

```bash
# Check daemon is running
sudo launchctl list | grep macscope
# Should show: com.macscope.vhid.relay

# Check socket exists
ls -la /tmp/macs_vhid_*.sock
# Should show: /tmp/macs_vhid_501.sock (or your UID)

# Test communication
echo '{"type":"ping"}' | nc -U /tmp/macs_vhid_$(id -u).sock
# Should return: {"status":"ok","message":"pong"}
```

---

## 🎮 Test Mouse Control

```bash
# Move mouse right 50 pixels
echo '{"type":"pointing_input","x":50,"y":0,"vertical_wheel":0,"horizontal_wheel":0,"buttons":0}' | nc -U /tmp/macs_vhid_$(id -u).sock

# Click left mouse button
echo '{"type":"pointing_input","x":0,"y":0,"vertical_wheel":0,"horizontal_wheel":0,"buttons":1}' | nc -U /tmp/macs_vhid_$(id -u).sock
sleep 0.1
echo '{"type":"pointing_input","x":0,"y":0,"vertical_wheel":0,"horizontal_wheel":0,"buttons":0}' | nc -U /tmp/macs_vhid_$(id -u).sock
```

---

## 🔍 Check Logs

```bash
# View daemon logs
tail -f /var/log/macscope-vhid.log

# View installation logs
cat /var/log/macscope-vhid-install.log
```

---

## ❌ Troubleshooting

### Daemon not running?

```bash
# Check driver status
systemextensionsctl list | grep Karabiner

# Restart daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
```

### Socket not found?

```bash
# Check permissions
ls -la /usr/local/bin/macscope-vhid

# View recent logs
tail -50 /var/log/macscope-vhid.log
```

### Driver not approved?

1. Open **System Settings** → **Privacy & Security**
2. Scroll down to "System software from developer..."
3. Click **Allow**
4. **Restart Mac**
5. Run installer again

---

## 🗑️ Uninstall

```bash
# Stop and remove
sudo launchctl bootout system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
sudo rm /Library/LaunchDaemons/com.macscope.vhid.relay.plist
sudo rm /usr/local/bin/macscope-vhid
rm /tmp/macs_vhid_*.sock
```

---

## 📚 More Information

- [Full Installation Guide](docs/INSTALL.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [GitHub Repository](https://github.com/yourusername/macscope)

---

## 🎯 Common Use Cases

### From Python
```python
import socket
import json

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(f"/tmp/macs_vhid_{os.getuid()}.sock")

# Move mouse
command = {"type": "pointing_input", "x": 10, "y": 5, "vertical_wheel": 0, "horizontal_wheel": 0, "buttons": 0}
sock.send(json.dumps(command).encode())

sock.close()
```

### From Swift
```swift
import Network

let socket = NWConnection(
    to: .unix(path: "/tmp/macs_vhid_\(getuid()).sock"),
    using: .tcp
)

let command = """
{"type":"pointing_input","x":10,"y":5,"vertical_wheel":0,"horizontal_wheel":0,"buttons":0}
"""

socket.send(content: command.data(using: .utf8), completion: .idempotent)
```

### From Shell
```bash
#!/bin/bash
SOCKET="/tmp/macs_vhid_$(id -u).sock"

move_mouse() {
    echo "{\"type\":\"pointing_input\",\"x\":$1,\"y\":$2,\"vertical_wheel\":0,\"horizontal_wheel\":0,\"buttons\":0}" | nc -U "$SOCKET"
}

move_mouse 50 0  # Move right
move_mouse 0 50  # Move down
```

---

**Ready to go! 🚀**
