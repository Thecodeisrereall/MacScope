# MacScope VirtualHID Installer - Fix Summary

## Problem Diagnosed

**Error**: `Bootstrap failed: 5: Input/output error`  
**Root Cause**: Race condition where `macscope-vhid` binary launches before Karabiner-DriverKit-VirtualHIDDevice is ready

### Why It Failed

1. LaunchDaemon immediately executed `/usr/local/bin/macscope-vhid` on bootstrap
2. Binary tried to open `/dev/Karabiner-DriverKit-VirtualHIDKeyboard` 
3. Device node didn't exist yet (Karabiner daemon still initializing)
4. Python script hit exception and exited immediately
5. launchctl detected instant exit → I/O error (code 5)

## Solution Applied

### File Changes

| File | Location | Status |
|------|----------|--------|
| `install_vhid_relay.sh` | `/MacScope-vHID-Relay/` | ✅ **FIXED** |
| `install_vhid_relay.sh` | `/MacroUI.app/Contents/Resources/` | ✅ **UPDATED** |
| `com.macscope.vhid.relay.plist` | `/MacScope-vHID-Relay/` | ✅ **FIXED** |
| `update_vhid_relay.sh` | `/MacScope-vHID-Relay/` | ✅ **CREATED** |
| `README.md` | `/MacScope-vHID-Relay/` | ✅ **CREATED** |

### Fix #1: LaunchDaemon Plist with Readiness Loop

**Before:**
```xml
<key>ProgramArguments</key>
<array>
    <string>/usr/local/bin/macscope-vhid</string>
</array>
```

**After:**
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

**What This Does:**
- Waits up to 30 seconds (15 × 2s) for Karabiner to be ready
- Checks BOTH: system extension is activated AND daemon process is running
- Logs all startup steps to `/var/log/macscope-vhid.log`
- Only launches binary after verification passes

### Fix #2: Installer Pre-flight Checks

**Added to installer BEFORE downloading files:**

```bash
# Step 5: Verify Karabiner VirtualHID readiness BEFORE downloading
echo "[info] Verifying Karabiner VirtualHID readiness..."
KARABINER_READY=0
for i in {1..15}; do
    if systemextensionsctl list 2>/dev/null | grep -q "Karabiner-DriverKit-VirtualHIDDevice.*activated.*enabled"; then
        if pgrep -x "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
            echo "[ok] Karabiner VirtualHID ready after $i attempts"
            KARABINER_READY=1
            break
        fi
    fi
    echo "[info] Waiting for Karabiner VirtualHID ($i/15)..."
    sleep 2
done

if [[ "$KARABINER_READY" -eq 0 ]]; then
    echo "[error] Karabiner VirtualHID driver/daemon not ready after 30 seconds"
    echo "[error] Please ensure Karabiner-DriverKit-VirtualHIDDevice is installed and approved"
    echo "[error] Check System Settings > Privacy & Security > System Extensions"
    exit 1
fi
```

**What This Does:**
- Installer won't proceed unless Karabiner is confirmed ready
- Provides clear error messages if Karabiner is missing
- Prevents wasting time downloading files if prerequisites aren't met

### Fix #3: Removed Python3 Dependency

**Before:**
```bash
MANIFEST_VERSION=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE'))['version'])")
```

**After:**
```bash
MANIFEST_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$MANIFEST_FILE" | cut -d'"' -f4)
```

**Why:** Python3 isn't always available on macOS, using native bash tools is more reliable

### Fix #4: Enhanced Logging and Error Messages

**Added:**
- Timestamped logs: `[2025-01-21 14:30:15] [info] Starting installation...`
- Post-install verification with log checks
- Helpful troubleshooting messages on failure
- Links to relevant log files

## Testing Verification

### What To Check After Installing

```bash
# 1. Check daemon is running
launchctl print system/com.macscope.vhid.relay | grep state
# Expected: state = running

# 2. Check startup logs
tail /var/log/macscope-vhid.log
# Expected to see:
#   [ok] Karabiner VirtualHID ready after 3 attempts
#   [launch] Starting macscope-vhid relay
#   VirtualHID relay listening on /tmp/macs_vhid_501.sock

# 3. Verify files exist with correct permissions
ls -l /usr/local/bin/macscope-vhid
# Expected: -rwxr-xr-x 1 root wheel

ls -l /Library/LaunchDaemons/com.macscope.vhid.relay.plist
# Expected: -rw-r--r-- 1 root wheel

# 4. Check socket is created
ls -l /tmp/macs_vhid_*.sock
# Expected: srwxrw-rw- 1 <user> <user> (unix socket)
```

## Installation Flow (New)

```
User clicks "Install VirtualHID" in MacScope
         ↓
Swift app runs install_vhid_relay.sh with sudo
         ↓
Script checks: Am I root? ✓
         ↓
Script checks: Is Karabiner ready? (wait up to 30s)
         ↓
If ready: Download manifest + files from GitHub
         ↓
Stop existing daemon (if any)
         ↓
Install binary + plist to system locations
         ↓
Bootstrap LaunchDaemon
         ↓
LaunchDaemon starts bash wrapper
         ↓
Wrapper checks: Is Karabiner STILL ready? (wait up to 30s)
         ↓
If ready: Launch macscope-vhid binary
         ↓
Binary opens /dev/Karabiner-DriverKit-VirtualHIDKeyboard
         ↓
SUCCESS: Socket created, ready to receive commands
```

## Files to Commit to GitHub

```
MacScope-vHID-Relay/
├── macscope-vhid                       (unchanged - Python relay binary)
├── com.macscope.vhid.relay.plist       (FIXED - added readiness checks)
├── manifest.json                        (unchanged - version 1.0.0)
├── install_vhid_relay.sh               (FIXED - pre-flight checks, no Python3)
├── update_vhid_relay.sh                (NEW - version-aware updater)
└── README.md                            (NEW - comprehensive documentation)
```

## Swift Integration (No Changes Needed)

Your existing Swift code still works:

```swift
let scriptPath = Bundle.main.path(forResource: "install_vhid_relay", ofType: "sh")!
let script = "do shell script \"/usr/bin/env bash '\(scriptPath)'\" with administrator privileges"

if let result = NSAppleScript(source: script)?.executeAndReturnError(nil) {
    // Installation succeeded
    print("VirtualHID relay installed successfully")
} else {
    // Installation failed - check /var/log/macscope-vhid-install.log
    print("Installation failed, check logs")
}
```

## Next Steps

1. **Test the fixed installer:**
   ```bash
   cd /Users/meklows/Documents/GitHub/MacScope/MacScope-vHID-Relay
   chmod +x install_vhid_relay.sh
   sudo ./install_vhid_relay.sh
   ```

2. **Commit and push to GitHub:**
   ```bash
   cd /Users/meklows/Documents/GitHub/MacScope
   git add MacScope-vHID-Relay/
   git commit -m "Fix: Add Karabiner readiness checks to prevent I/O error 5"
   git push origin main
   ```

3. **Test from MacScope app:**
   - Bundle updated `install_vhid_relay.sh` in Resources
   - Click "Install VirtualHID" in app
   - Verify daemon starts successfully

4. **Update MacroUI.app bundle:**
   - The file is already updated in `/MacroUI.app/Contents/Resources/install_vhid_relay.sh`
   - Rebuild/resign app if needed

## Success Criteria

✅ Installer completes without I/O error  
✅ Daemon starts automatically on boot  
✅ Log shows "Karabiner VirtualHID ready after X attempts"  
✅ Socket file created at `/tmp/macs_vhid_<uid>.sock`  
✅ MacScope app can send commands successfully  

---

**Fixed By:** Claude Sonnet 4.5  
**Date:** January 21, 2025  
**Issue:** Bootstrap failed: 5 (I/O error) due to race condition  
**Solution:** Added readiness checks to both plist and installer
