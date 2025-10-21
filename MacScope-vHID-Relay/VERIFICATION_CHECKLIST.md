# Installation Verification Checklist

## ✅ Fixed Files

1. **install_vhid_relay.sh** - Added Karabiner readiness checks BEFORE bootstrap
2. **com.macscope.vhid.relay.plist** - Added startup wait loop with 30s timeout
3. **Binary ad-hoc signing** - Applied if unsigned

## 🧪 Test Installation

### Step 1: Run Test Script
```bash
cd /Users/meklows/Documents/GitHub/MacScope/MacScope-vHID-Relay
chmod +x test_installation.sh
sudo ./test_installation.sh
```

**Expected output:**
```
✅ PASS: Karabiner driver is activated and enabled
✅ PASS: Karabiner daemon running (PID: 1234)
```

### Step 2: Run Installer
```bash
cd /Users/meklows/Documents/GitHub/MacScope/MacScope-vHID-Relay
chmod +x install_vhid_relay.sh
sudo ./install_vhid_relay.sh
```

**Expected output:**
```
[ok] Running as root
[ok] Karabiner VirtualHID ready after 3 attempts (waited 6s)
[ok] Manifest downloaded
[ok] Manifest version: 1.0.0
[ok] Downloaded macscope-vhid
[ok] Downloaded com.macscope.vhid.relay.plist
[ok] Installed macscope-vhid binary
[ok] Installed LaunchDaemon plist
[ok] Daemon bootstrapped
[ok] Daemon is registered in launchctl
[ok] Daemon started successfully and is listening
=== Installation Complete ===
```

### Step 3: Verify Daemon Status
```bash
# Check daemon is running
sudo launchctl print system/com.macscope.vhid.relay | grep state
```
**Expected:** `state = running`

```bash
# Check daemon logs
sudo tail -20 /var/log/macscope-vhid.log
```
**Expected:**
```
[startup] waiting for Karabiner...
[ok] Karabiner ready after 3 tries
[launch] Starting macscope-vhid relay
VirtualHID relay listening on /tmp/macs_vhid_501.sock
```

### Step 4: Check Socket Created
```bash
ls -l /tmp/macs_vhid_*.sock
```
**Expected:** `srwxrw-rw- 1 <user> <user> 0 Jan 21 14:30 /tmp/macs_vhid_501.sock`

## 🔍 Verification Commands

### Before Installation
```bash
# Verify Karabiner is ready (MUST pass before installing)
systemextensionsctl list | grep Karabiner
# Should show: activated enabled

pgrep -x "Karabiner-VirtualHIDDevice-Daemon"
# Should return a PID number
```

### After Installation
```bash
# 1. Check files exist
ls -l /usr/local/bin/macscope-vhid
# Expected: -rwxr-xr-x 1 root wheel

ls -l /Library/LaunchDaemons/com.macscope.vhid.relay.plist
# Expected: -rw-r--r-- 1 root wheel

# 2. Check daemon state
sudo launchctl print system/com.macscope.vhid.relay

# 3. View full logs
sudo tail -50 /var/log/macscope-vhid-install.log
sudo tail -50 /var/log/macscope-vhid.log

# 4. Test from MacScope app
# Open MacScope → VirtualHID Manager → Test keyboard/mouse
```

## 🚨 Troubleshooting

### Error: "Karabiner VirtualHID driver/daemon not ready"

**Solution:**
1. Install Karabiner-DriverKit-VirtualHIDDevice:
   ```bash
   # Download .pkg from:
   # https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases
   
   sudo installer -pkg Karabiner-DriverKit-VirtualHIDDevice-*.pkg -target /
   ```

2. Approve in System Settings:
   - System Settings → Privacy & Security
   - Click "Allow" for Karabiner-DriverKit-VirtualHIDDevice
   - **Restart macOS**

3. Verify:
   ```bash
   systemextensionsctl list | grep Karabiner
   # Must show: activated enabled
   ```

### Error: "Bootstrap failed: 5"

**This should now be FIXED!** If you still see this:

1. Check Karabiner is running:
   ```bash
   pgrep -x "Karabiner-VirtualHIDDevice-Daemon"
   ```

2. Check devices exist:
   ```bash
   ls /dev/Karabiner*
   # Should list keyboard and pointing devices
   ```

3. View daemon startup logs:
   ```bash
   sudo tail -50 /var/log/macscope-vhid.log
   ```

### Error: "Virtual keyboard device not found"

**This should now be FIXED!** The plist now waits 30s for Karabiner.

If still occurring:
```bash
# Check if daemon waited
sudo grep "waiting for Karabiner" /var/log/macscope-vhid.log

# Check if devices appeared
sudo grep "Karabiner ready" /var/log/macscope-vhid.log
```

## 📝 Success Criteria

- [ ] Test script passes all checks
- [ ] Installer completes without errors
- [ ] No "Bootstrap failed: 5" error
- [ ] No "Virtual keyboard device not found" error
- [ ] Daemon log shows "Karabiner ready after X tries"
- [ ] Daemon log shows "VirtualHID relay listening"
- [ ] Socket file exists: `/tmp/macs_vhid_*.sock`
- [ ] `launchctl print` shows `state = running`
- [ ] MacScope app can send keyboard/mouse commands

## 🎯 What Changed

### install_vhid_relay.sh
**Before:** Downloaded files → Installed → Bootstrapped (CRASH!)
**After:** **Check Karabiner ready → Wait 30s** → Download → Install → Bootstrap ✅

### com.macscope.vhid.relay.plist
**Before:** Immediately launched `/usr/local/bin/macscope-vhid` (CRASH!)
**After:** Bash wrapper → **Wait for Karabiner (15 tries × 2s)** → Launch binary ✅

### Key Fix
**Double readiness check:**
1. Installer verifies Karabiner before bootstrap
2. LaunchDaemon verifies Karabiner before launching binary

This ensures the relay NEVER starts before Karabiner is ready!

## 📤 Next Steps

1. Test installation with checklist above
2. If all passes, commit to GitHub:
   ```bash
   cd /Users/meklows/Documents/GitHub/MacScope
   git add MacScope-vHID-Relay/
   git commit -m "Fix: Add Karabiner readiness checks (fixes I/O error 5)"
   git push origin main
   ```

3. Test from MacScope app
4. Celebrate! 🎉

---
**Status:** ✅ Ready for testing  
**Expected Result:** No more "Bootstrap failed: 5" errors!
