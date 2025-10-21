# Troubleshooting Guide

Common issues and solutions for MacScope VirtualHID relay.

## Quick Diagnostics

Run this command to get system status:

```bash
echo "=== System Info ===" && \
sw_vers && \
echo -e "\n=== Driver Status ===" && \
systemextensionsctl list | grep Karabiner && \
echo -e "\n=== Daemon Status ===" && \
sudo launchctl list | grep macscope && \
echo -e "\n=== Binary Check ===" && \
ls -la /usr/local/bin/macscope-vhid && \
echo -e "\n=== Socket Check ===" && \
ls -la /tmp/macs_vhid_*.sock 2>/dev/null || echo "No sockets found" && \
echo -e "\n=== Recent Logs ===" && \
tail -20 /var/log/macscope-vhid.log
```

---

## Installation Issues

### Driver Won't Install

**Symptoms:**
- Installer fails at driver stage
- "Operation not permitted" errors

**Solutions:**

1. Check System Integrity Protection (SIP):
   ```bash
   csrutil status
   ```
   SIP should be enabled for DriverKit extensions.

2. Ensure you have Full Disk Access for Terminal:
   - System Settings → Privacy & Security → Full Disk Access
   - Add Terminal.app

3. Try manual driver installation:
   ```bash
   curl -L -o /tmp/driver.pkg \
     "https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v6.4.0/Karabiner-DriverKit-VirtualHIDDevice-6.4.0.pkg"
   sudo installer -pkg /tmp/driver.pkg -target /
   ```

### Binary Won't Copy

**Symptoms:**
- "Permission denied" when copying binary
- "Operation not permitted"

**Solutions:**

1. Run with proper sudo:
   ```bash
   sudo cp /path/to/macscope-vhid /usr/local/bin/
   ```

2. Check /usr/local/bin exists:
   ```bash
   sudo mkdir -p /usr/local/bin
   ```

3. Verify source binary exists:
   ```bash
   file /path/to/macscope-vhid
   ```

---

## Runtime Issues

### Daemon Won't Start

**Symptoms:**
- `launchctl list` doesn't show daemon
- Immediate crash after bootstrap

**Check 1: Binary Permissions**
```bash
ls -la /usr/local/bin/macscope-vhid
# Should show: -rwxr-xr-x  1 root  wheel
```

**Fix:**
```bash
sudo chown root:wheel /usr/local/bin/macscope-vhid
sudo chmod 755 /usr/local/bin/macscope-vhid
```

**Check 2: Plist Syntax**
```bash
plutil -lint /Library/LaunchDaemons/com.macscope.vhid.relay.plist
# Should show: OK
```

**Check 3: Daemon Logs**
```bash
tail -50 /var/log/macscope-vhid.log
```

Look for:
- "Permission denied"
- "Library not loaded"
- Segmentation faults

**Check 4: Manual Launch Test**
```bash
# Try running manually
sudo /usr/local/bin/macscope-vhid
```

### Socket Not Created

**Symptoms:**
- Daemon running but no socket file
- "Connection refused" errors

**Check 1: Verify Daemon is Really Running**
```bash
ps aux | grep macscope-vhid
```

**Check 2: Check Socket Permissions**
```bash
ls -la /tmp/macs_vhid_*.sock
```

**Check 3: Daemon Logs**
```bash
grep -i "socket" /var/log/macscope-vhid.log
```

**Check 4: Test Socket Creation Manually**
```bash
# Stop daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.macscope.vhid.relay.plist

# Run binary manually
sudo /usr/local/bin/macscope-vhid &

# Check for socket
ls -la /tmp/macs_vhid_*.sock

# Stop manual instance
sudo killall macscope-vhid
```

### Driver Not Connecting

**Symptoms:**
- "Driver not connected" in logs
- "Driver version mismatch" errors
- Commands sent but nothing happens

**Check 1: Driver Activation Status**
```bash
systemextensionsctl list | grep Karabiner
```

Should show: `[activated enabled]`

**States and Meanings:**
- `[activated enabled]` - ✅ Working
- `[activated waiting for user]` - ⚠️ Needs approval in System Settings
- `[staged]` - ⚠️ Waiting for reboot
- Not listed - ❌ Not installed

**Check 2: Driver Version**
```bash
/Library/Application\ Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/version
```

Must be v6.4.0 or later.

**Check 3: Restart Driver**
```bash
# Deactivate
sudo /Library/Application\ Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/deactivate_driver.sh

# Reboot
sudo reboot

# After reboot, activate
sudo /Library/Application\ Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/activate_driver.sh
```

---

## Communication Issues

### Commands Not Working

**Symptoms:**
- Socket responds but commands don't execute
- No errors but no mouse/keyboard input

**Debug Step 1: Test Basic Connectivity**
```bash
echo '{"type":"ping"}' | nc -U /tmp/macs_vhid_$(id -u).sock
```

Expected: `{"status":"ok","message":"pong"}`

**Debug Step 2: Test with Verbose Logging**

Add debug output to daemon (if you have source):
```cpp
std::cout << "Received command: " << json.dump() << std::endl;
```

**Debug Step 3: Check Driver Status in Logs**
```bash
grep -i "driver" /var/log/macscope-vhid.log
```

Look for:
- "driver_connected: 1"
- "driver_activated: 1"
- "virtual_hid_keyboard_ready: 1"
- "virtual_hid_pointing_ready: 1"

All should be `1` for full functionality.

### JSON Parse Errors

**Symptoms:**
- "Parse error" in logs
- Malformed JSON complaints

**Solutions:**

1. Validate JSON before sending:
   ```bash
   echo '{"type":"pointing_input","x":10,"y":10}' | jq .
   ```

2. Ensure proper newlines/terminators

3. Check for special characters

4. Use proper escaping:
   ```bash
   echo "{\"type\":\"ping\"}" | nc -U /tmp/macs_vhid_$(id -u).sock
   ```

---

## Performance Issues

### High CPU Usage

**Symptoms:**
- Daemon using excessive CPU
- System slowdown

**Check 1: Throttle Interval**

The LaunchDaemon has a 5-second throttle. Check if it's crashing repeatedly:
```bash
grep -c "crashed" /var/log/macscope-vhid.log
```

**Check 2: Memory Leaks**
```bash
sudo leaks macscope-vhid
```

**Solution:** Restart daemon:
```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
```

### Slow Response

**Symptoms:**
- Delayed mouse/keyboard input
- Commands queue up

**Check 1: Socket Buffer**

Large messages might be getting buffered. Test with small commands first.

**Check 2: Event Queue**

Check if driver is processing events:
```bash
ioreg -l -w 0 | grep Karabiner
```

---

## System Extension Issues

### "System Extension Blocked"

**Symptoms:**
- Notification about blocked extension
- Driver won't activate

**Solution:**

1. Open System Settings → Privacy & Security
2. Scroll to bottom of page
3. Click "Allow" next to blocked extension notification
4. Restart Mac
5. Run installer again

### Multiple Driver Versions

**Symptoms:**
- Conflicting driver installations
- "Driver already loaded" errors

**Solution:**

Remove all versions and reinstall:
```bash
# Deactivate all
sudo systemextensionsctl uninstall org.pqrs.Karabiner-DriverKit-VirtualHIDDevice

# Reboot
sudo reboot

# After reboot, reinstall fresh
sudo installer -pkg /path/to/driver.pkg -target /
```

---

## Log Analysis

### Understanding Log Levels

```
[INFO]    - Normal operation
[WARNING] - Non-fatal issues
[ERROR]   - Fatal errors
[DEBUG]   - Detailed debugging (if compiled with debug)
```

### Common Log Messages

**"Socket created: /tmp/macs_vhid_501.sock"**
✅ Good - daemon started successfully

**"Driver not connected"**
⚠️ Driver not active - check `systemextensionsctl list`

**"Permission denied"**
❌ Binary permissions issue - run: `sudo chmod 755 /usr/local/bin/macscope-vhid`

**"Library not loaded"**
❌ Missing dependencies - binary may need rebuild

**"Segmentation fault"**
❌ Critical bug - file issue report with backtrace

---

## Getting Help

If you've tried everything above:

1. Gather diagnostics:
   ```bash
   sudo ./scripts/diagnostics.sh > ~/Desktop/macscope-diagnostics.txt
   ```

2. Open an issue with:
   - macOS version
   - Installation method used
   - Full error logs
   - Output from diagnostics script

3. Include recent changes:
   - Recent macOS updates
   - Other software installed
   - System modifications

---

## Diagnostic Script

Create this as `scripts/diagnostics.sh`:

```bash
#!/bin/bash
echo "=== System Info ==="
sw_vers
echo ""
echo "=== Driver Status ==="
systemextensionsctl list
echo ""
echo "=== Daemon Status ==="
launchctl list | grep macscope
echo ""
echo "=== Files ==="
ls -la /usr/local/bin/macscope-vhid
ls -la /Library/LaunchDaemons/com.macscope.vhid.relay.plist
ls -la /tmp/macs_vhid_*.sock
echo ""
echo "=== Recent Logs ==="
tail -100 /var/log/macscope-vhid.log
```

Make it executable:
```bash
chmod +x scripts/diagnostics.sh
```
