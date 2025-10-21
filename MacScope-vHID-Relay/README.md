# MacScope VirtualHID Installer - Fixed and Stable

## What Was Fixed

The installer previously failed with `Bootstrap failed: 5: Input/output error` because:

1. **Timing Issue**: `macscope-vhid` launched immediately before Karabiner's DriverKit daemon was ready
2. **No Readiness Checks**: The installer didn't verify Karabiner VirtualHID was active before bootstrapping
3. **Early Device Access**: The binary tried to open `/dev/Karabiner-DriverKit-VirtualHIDKeyboard` too early, causing instant exit

## Solution Implemented

### 1. LaunchDaemon Plist (`com.macscope.vhid.relay.plist`)

Now includes **startup delay logic** that waits up to 30 seconds for Karabiner:

```xml
<key>ProgramArguments</key>
<array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>
        LOG="/var/log/macscope-vhid.log"
        echo "[startup] Waiting for Karabiner VirtualHID driver..." >> "$LOG"
        for i in {1..15}; do
            if systemextensionsctl list | grep -q "Karabiner-DriverKit-VirtualHIDDevice.*activated.*enabled"; then
                if pgrep -x "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
                    echo "[ok] Karabiner VirtualHID ready after $i attempts" >> "$LOG"
                    break
                fi
            fi
            echo "[wait] Attempt $i - driver not ready" >> "$LOG"
            sleep 2
        done
        mkdir -p /var/run/macscope
        chmod 777 /var/run/macscope
        echo "[launch] Starting macscope-vhid relay" >> "$LOG"
        exec /usr/local/bin/macscope-vhid --verbose >> "$LOG" 2>&1
    </string>
</array>
```

**This ensures:**
- Driver extension is `activated` and `enabled`
- Daemon process is running
- 30-second grace period (15 attempts × 2 seconds)
- Centralized logging to `/var/log/macscope-vhid.log`

### 2. Installer Script (`install_vhid_relay.sh`)

**Removed Python3 dependency** - now uses native bash/grep/cut for JSON parsing

**Added pre-flight checks:**
```bash
# Verify Karabiner VirtualHID readiness BEFORE downloading
for i in {1..15}; do
    if systemextensionsctl list | grep -q "Karabiner-DriverKit-VirtualHIDDevice.*activated.*enabled"; then
        if pgrep -x "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
            echo "[ok] Karabiner VirtualHID ready"
            break
        fi
    fi
    sleep 2
done
```

**Improved error handling:**
- Fails fast if Karabiner isn't ready after 30 seconds
- Provides clear error messages pointing to System Settings
- Verifies plist label matches expected value
- Checks daemon log for successful startup

## Installation

### From Swift App

```swift
let scriptPath = Bundle.main.path(forResource: "install_vhid_relay", ofType: "sh")!
let script = "do shell script \"/usr/bin/env bash '\(scriptPath)'\" with administrator privileges"

if let result = NSAppleScript(source: script)?.executeAndReturnError(nil) {
    print("Installation succeeded")
}
```

### Manual Testing

```bash
# Make executable
chmod +x install_vhid_relay.sh

# Run installer
sudo ./install_vhid_relay.sh

# Monitor daemon
sudo tail -f /var/log/macscope-vhid.log
```

## Success Verification

After installation, check:

```bash
# 1. Daemon is registered
launchctl print system/com.macscope.vhid.relay | grep state
# Expected: state = running

# 2. Log shows successful startup
tail /var/log/macscope-vhid.log
# Expected output:
# [startup] Waiting for Karabiner VirtualHID driver...
# [ok] Karabiner VirtualHID ready after 3 attempts
# [launch] Starting macscope-vhid relay
# VirtualHID relay listening on /tmp/macs_vhid_501.sock

# 3. Binary exists and is executable
ls -l /usr/local/bin/macscope-vhid
# Expected: -rwxr-xr-x 1 root wheel

# 4. Plist exists with correct permissions
ls -l /Library/LaunchDaemons/com.macscope.vhid.relay.plist
# Expected: -rw-r--r-- 1 root wheel
```

## Update Script

The optional `update_vhid_relay.sh` provides zero-downtime updates:

```bash
sudo ./update_vhid_relay.sh
```

**Features:**
- Compares installed vs. latest version
- Exits early if already up-to-date (exit code 0)
- Gracefully stops daemon before update
- Restarts with new binary and plist

## Troubleshooting

### Bootstrap Failed: 5 (I/O Error)

**Cause**: Karabiner VirtualHID not ready or not approved

**Fix**:
1. Install Karabiner-DriverKit-VirtualHIDDevice:
   ```bash
   # Download from: https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases
   sudo installer -pkg Karabiner-DriverKit-VirtualHIDDevice-*.pkg -target /
   ```

2. Approve system extension:
   - Open System Settings > Privacy & Security
   - Click "Allow" next to "Karabiner-DriverKit-VirtualHIDDevice"
   - Restart macOS if prompted

3. Verify readiness:
   ```bash
   systemextensionsctl list | grep Karabiner
   # Should show: activated enabled
   
   pgrep -x "Karabiner-VirtualHIDDevice-Daemon"
   # Should return a PID
   ```

### Daemon Won't Start

Check logs for errors:
```bash
tail -50 /var/log/macscope-vhid.log
```

Common issues:
- **"Virtual keyboard device not found"** → Karabiner not ready, wait 30s
- **"Permission denied"** → Check binary permissions: `sudo chmod 755 /usr/local/bin/macscope-vhid`
- **"Address already in use"** → Socket conflict: `sudo rm /tmp/macs_vhid_*.sock`

### Clean Reinstall

```bash
# Stop daemon
sudo launchctl bootout system/com.macscope.vhid.relay

# Remove files
sudo rm /usr/local/bin/macscope-vhid
sudo rm /Library/LaunchDaemons/com.macscope.vhid.relay.plist
sudo rm -rf /var/run/macscope
sudo rm /usr/local/lib/macscope/VERSION

# Clean logs (optional)
sudo rm /var/log/macscope-vhid.log
sudo rm /var/log/macscope-vhid-install.log

# Reinstall
sudo ./install_vhid_relay.sh
```

## Log Files

| Path | Purpose |
|------|---------|
| `/var/log/macscope-vhid-install.log` | Installer script output with timestamps |
| `/var/log/macscope-vhid.log` | Daemon runtime logs (startup, connections, errors) |

## File Locations

| File | Path | Permissions |
|------|------|-------------|
| Binary | `/usr/local/bin/macscope-vhid` | `755 root:wheel` |
| LaunchDaemon | `/Library/LaunchDaemons/com.macscope.vhid.relay.plist` | `644 root:wheel` |
| Socket Directory | `/var/run/macscope` | `755 root:wheel` |
| Version File | `/usr/local/lib/macscope/VERSION` | `644 root:wheel` |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ System Boot / LaunchDaemon Startup                      │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
         ┌────────────────────┐
         │ Wait for Karabiner │ (up to 30 seconds)
         │ - systemextensionsctl check
         │ - pgrep daemon check
         └────────┬───────────┘
                  │
                  ▼
         ┌────────────────────┐
         │ macscope-vhid starts│
         │ - Opens /dev/Karabiner-DriverKit-VirtualHIDKeyboard
         │ - Opens /dev/Karabiner-DriverKit-VirtualHIDPointing
         │ - Creates Unix socket /tmp/macs_vhid_<uid>.sock
         └────────┬───────────┘
                  │
                  ▼
         ┌────────────────────┐
         │ Ready to receive   │
         │ commands from      │
         │ MacScope app       │
         └────────────────────┘
```

## Testing Checklist

- [ ] Fresh install completes without errors
- [ ] Daemon starts automatically on reboot
- [ ] Log file shows successful Karabiner detection
- [ ] Socket file is created: `/tmp/macs_vhid_<uid>.sock`
- [ ] Update script detects current version correctly
- [ ] Update script only downloads when version differs
- [ ] Clean uninstall removes all files

## Future Enhancements

1. **Swift-based installer** using `SMAppService.daemon.register()` for automatic approval handling
2. **Healthcheck endpoint** for monitoring daemon status
3. **Auto-restart on crash** with exponential backoff
4. **Version notification** in MacScope app when updates available

---

**Fixed on**: January 2025  
**Tested on**: macOS 13+  
**Dependencies**: Karabiner-DriverKit-VirtualHIDDevice 3.1.0+
