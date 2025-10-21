# Installation Guide

Complete guide for installing MacScope VirtualHID relay system.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Install](#quick-install)
3. [Manual Installation](#manual-installation)
4. [Building from Source](#building-from-source)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Uninstallation](#uninstallation)

---

## Prerequisites

### System Requirements

- macOS 13.0 (Ventura) or later
- Administrator (sudo) access
- At least 50MB free disk space

### Required Software

- Karabiner-DriverKit-VirtualHIDDevice v6.4.0+ (auto-installed if missing)

---

## Quick Install

The fastest way to install is using the one-line installer:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/macscope/main/scripts/install_vhid_relay.sh | sudo bash
```

This will:
1. Check system requirements
2. Install Karabiner driver if needed
3. Install the relay binary
4. Configure and start the LaunchDaemon
5. Verify the installation

---

## Manual Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/macscope.git
cd macscope
```

### Step 2: Add Your Binary

Copy your compiled relay binary to the payload directory:

```bash
cp /path/to/your/macscope-vhid ./payload/
chmod +x ./payload/macscope-vhid
```

### Step 3: Run Installer

```bash
sudo ./scripts/install_vhid_relay.sh
```

### Step 4: Approve System Extension (if needed)

If this is the first installation:

1. Open **System Settings** → **Privacy & Security**
2. Look for "System software from developer..." notification
3. Click **Allow**
4. Restart your Mac

### Step 5: Verify Installation

After reboot, verify the daemon is running:

```bash
sudo launchctl list | grep macscope
```

You should see `com.macscope.vhid.relay` in the list.

---

## Building from Source

If you want to build and distribute a .pkg installer:

### Step 1: Prepare Your Binary

Ensure your binary is in the `payload/` directory:

```bash
# Example: copy from your build directory
cp ../MacScopeClient/build/Release/macscope-vhid ./payload/
```

### Step 2: Build Package

```bash
cd build
./build.sh
```

This creates `MacScope_VirtualHID_Installer.pkg` on your Desktop.

### Step 3: Install Package

```bash
sudo installer -pkg ~/Desktop/MacScope_VirtualHID_Installer.pkg -target /
```

Or double-click the .pkg file to use the GUI installer.

---

## Verification

### Check Daemon Status

```bash
# Check if daemon is running
sudo launchctl list | grep macscope

# View daemon logs
tail -f /var/log/macscope-vhid.log
```

### Test Socket Communication

```bash
# Test ping command
echo '{"type":"ping"}' | nc -U /tmp/macs_vhid_$(id -u).sock
```

Expected response: `{"status":"ok","message":"pong"}`

### Verify Driver

```bash
systemextensionsctl list | grep Karabiner
```

You should see `[activated enabled]` status.

---

## Troubleshooting

### Issue: Daemon Won't Start

**Symptoms:** `launchctl list` doesn't show the daemon

**Solutions:**

1. Check if binary exists and is executable:
   ```bash
   ls -la /usr/local/bin/macscope-vhid
   ```

2. Check installation logs:
   ```bash
   cat /var/log/macscope-vhid-install.log
   ```

3. Try manual bootstrap:
   ```bash
   sudo launchctl bootstrap system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
   ```

### Issue: Socket Not Created

**Symptoms:** Cannot connect to socket

**Solutions:**

1. Check daemon logs:
   ```bash
   tail -50 /var/log/macscope-vhid.log
   ```

2. Verify driver is activated:
   ```bash
   systemextensionsctl list
   ```

3. Restart daemon:
   ```bash
   sudo launchctl bootout system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
   sudo launchctl bootstrap system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
   ```

### Issue: Permission Denied

**Symptoms:** Binary won't execute

**Solutions:**

1. Fix binary permissions:
   ```bash
   sudo chown root:wheel /usr/local/bin/macscope-vhid
   sudo chmod 755 /usr/local/bin/macscope-vhid
   ```

2. Check if binary is blocked by Gatekeeper:
   ```bash
   xattr -d com.apple.quarantine /usr/local/bin/macscope-vhid
   ```

### Issue: Driver Not Activated

**Symptoms:** Driver shows `[activated waiting for user]`

**Solutions:**

1. Open System Settings → Privacy & Security
2. Approve the Karabiner extension
3. Restart your Mac
4. Run installer again after reboot

---

## Uninstallation

### Complete Removal

```bash
# Stop daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.macscope.vhid.relay.plist

# Remove files
sudo rm /Library/LaunchDaemons/com.macscope.vhid.relay.plist
sudo rm /usr/local/bin/macscope-vhid

# Clean up sockets and logs
rm /tmp/macs_vhid_*.sock
sudo rm /var/log/macscope-vhid*.log
```

### Remove Driver (Optional)

If you also want to remove the Karabiner driver:

```bash
# Uninstall driver
sudo /Library/Application\ Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/deactivate_driver.sh

# Restart required
sudo reboot
```

---

## Additional Resources

- [GitHub Repository](https://github.com/yourusername/macscope)
- [Issue Tracker](https://github.com/yourusername/macscope/issues)
- [API Documentation](./API.md)
- [Contributing Guide](../CONTRIBUTING.md)

---

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review daemon logs: `/var/log/macscope-vhid.log`
3. Search [existing issues](https://github.com/yourusername/macscope/issues)
4. Open a new issue with:
   - macOS version (`sw_vers`)
   - Installation logs
   - Daemon logs
   - Steps to reproduce
