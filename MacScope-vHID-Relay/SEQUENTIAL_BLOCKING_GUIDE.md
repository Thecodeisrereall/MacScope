# Sequential Blocking Installation - Reference Guide

## 🎯 What Changed

The installer now uses **strict sequential blocking** with mandatory verification at each stage. No step proceeds until the previous step is confirmed successful.

## 📋 Installation Stages (14 Total)

### Stage 1: Fresh Sudo Authentication
```bash
sudo -k          # Clear cached credentials
sudo true        # Request fresh password
```
**Blocks until:** User enters valid sudo password

### Stage 2: Activate Karabiner Driver
```bash
/Applications/.Karabiner-VirtualHIDDevice-Manager.app/.../Karabiner-VirtualHIDDevice-Manager activate
```
**Blocks until:** Command completes (may require user approval in System Settings)

### Stage 3: Wait for Driver Activation ⏱️
```bash
systemextensionsctl list | grep "Karabiner-DriverKit-VirtualHIDDevice.*activated.*enabled"
```
**Blocks until:** Driver shows `[activated enabled]` status  
**Timeout:** 30 seconds (15 attempts × 2s)  
**Failure:** Exits with instructions to approve in System Settings

### Stage 4: Re-authenticate Sudo
```bash
sudo -k          # Clear cached credentials again
sudo true        # Request password for daemon launch
```
**Blocks until:** User enters valid sudo password (may prompt again)

### Stage 5: Launch Karabiner Daemon
```bash
sudo pkill -9 -x "Karabiner-VirtualHIDDevice-Daemon"  # Kill existing
sudo /Library/Application Support/.../Karabiner-VirtualHIDDevice-Daemon &
```
**Blocks until:** Launch command completes

### Stage 6: Wait for Daemon Process ⏱️
```bash
pgrep -x "Karabiner-VirtualHIDDevice-Daemon"
```
**Blocks until:** Daemon process is running and returns a PID  
**Timeout:** 30 seconds (15 attempts × 2s)  
**Failure:** Exits with process list

### Stage 7: Prepare Directories
```bash
mkdir -p /usr/local/bin /Library/LaunchDaemons /var/run/macscope /usr/local/lib/macscope
chmod 755 + chown root:wheel
```
**Blocks until:** All directories created with correct permissions

### Stage 8: Download Manifest & Files
```bash
curl manifest.json
curl macscope-vhid
curl com.macscope.vhid.relay.plist
```
**Blocks until:** All files downloaded successfully  
**Failure:** Exits on network error or missing files

### Stage 9: Install Binary
```bash
cp macscope-vhid /usr/local/bin/
chmod 755 + chown root:wheel
codesign -s - --force /usr/local/bin/macscope-vhid
```
**Blocks until:** Binary installed and ad-hoc signed

### Stage 10: Install LaunchDaemon Plist
```bash
cp com.macscope.vhid.relay.plist /Library/LaunchDaemons/
chmod 644 + chown root:wheel
plutil -extract Label (validate)
```
**Blocks until:** Plist installed and label validated

### Stage 11: Clean Stale Sockets
```bash
rm -f /var/run/macscope/vhid_*.sock
rm -f /tmp/macs_vhid_*.sock
```
**Blocks until:** Socket cleanup complete

### Stage 12: Bootstrap LaunchDaemon
```bash
sudo launchctl bootout system/com.macscope.vhid.relay
sudo launchctl bootstrap system /Library/LaunchDaemons/com.macscope.vhid.relay.plist
```
**Blocks until:** Bootstrap command completes  
**Failure:** Exits with launchctl error details

### Stage 13: Verify Daemon Registration ⏱️
```bash
sudo launchctl print system/com.macscope.vhid.relay
```
**Blocks until:** Daemon shows as registered with launchctl  
**Timeout:** 30 seconds (15 attempts × 2s)  
**Failure:** Exits if daemon not registered

### Stage 14: Record Version
```bash
echo "1.0.0" > /usr/local/lib/macscope/VERSION
```
**Blocks until:** Version file written

## 🔒 Key Features

### Strict Blocking
- Each stage MUST complete successfully before next stage begins
- No parallel execution or optimistic assumptions
- Clear `[stage N]`, `[ok]`, `[wait]`, `[error]` messages

### Multiple Sudo Prompts
- Stage 1: Initial authentication
- Stage 4: Re-authentication for daemon launch
- Stage 12+: Final authentication for launchctl operations

**Why?** Each critical operation gets fresh credentials to avoid permission issues

### Retry Loops (30s timeout)
Three stages have blocking retry loops:
- **Stage 3:** Driver activation (systemextensionsctl)
- **Stage 6:** Daemon process (pgrep)
- **Stage 13:** LaunchDaemon registration (launchctl print)

### Fail-Fast Behavior
Any stage failure = immediate exit with:
- Timestamped error message
- Current state information
- Actionable next steps

## 📊 Expected Timeline

**Successful installation:**
```
Stage 1:  Immediate (password entry)
Stage 2:  1-3 seconds (activation command)
Stage 3:  2-30 seconds (driver check)
Stage 4:  Immediate (password entry)
Stage 5:  1-2 seconds (daemon launch)
Stage 6:  2-10 seconds (daemon check)
Stage 7:  <1 second (mkdir)
Stage 8:  2-5 seconds (downloads)
Stage 9:  <1 second (binary install)
Stage 10: <1 second (plist install)
Stage 11: <1 second (cleanup)
Stage 12: 1-2 seconds (bootstrap)
Stage 13: 2-5 seconds (verification)
Stage 14: <1 second (version file)
----------------------------
Total:    ~15-60 seconds
```

**First-time installation (requires approval):**
- User must approve system extension in System Settings
- Stage 3 will wait up to 30 seconds
- May need manual intervention → rerun installer after approval

## 🧪 Testing

```bash
# Make executable
cd /Users/meklows/Documents/GitHub/MacScope/MacScope-vHID-Relay
chmod +x install_vhid_relay.sh

# Run installer
sudo ./install_vhid_relay.sh

# Expected output (abbreviated):
[stage 1] Requesting fresh sudo authentication...
Password: ****
[ok] Sudo authenticated

[stage 2] Activating Karabiner-DriverKit-VirtualHIDDevice...
[ok] Activation command completed

[stage 3] Waiting for driver activation [activated enabled]...
[info] Checking driver status (attempt 3/15)...
[ok] Driver is activated and enabled

[stage 4] Re-authenticating sudo for daemon launch...
Password: ****
[ok] Sudo re-authenticated

[stage 5] Launching Karabiner-VirtualHIDDevice-Daemon...
[ok] Daemon launched with PID: 1234

[stage 6] Waiting for daemon process to be running...
[ok] Daemon is running (PID: 1234)

...

[stage 13] Verifying daemon registration...
[ok] Daemon registered with launchctl (state: running)

=== Installation Complete ===
```

## 🚨 Common Scenarios

### Scenario 1: First Install (Extension Not Approved)
```
[stage 3] Waiting for driver activation...
[error] Driver failed to activate after 30 seconds
[error] Action required:
        1. Open System Settings → Privacy & Security
        2. Approve 'Karabiner-DriverKit-VirtualHIDDevice'
        3. Restart this installer
```
**Action:** User approves → rerun installer

### Scenario 2: Daemon Already Running
```
[stage 5] Launching Karabiner-VirtualHIDDevice-Daemon...
[info] Stopping any existing daemon instances...
[info] Starting daemon...
[ok] Daemon launched
```
**Action:** None, installer handles cleanup

### Scenario 3: Sudo Timeout Between Stages
```
[stage 4] Re-authenticating sudo...
Password: ****
[ok] Sudo re-authenticated
```
**Action:** User re-enters password (expected behavior)

## 📝 Verification After Install

```bash
# 1. Check all stages completed
sudo tail -100 /var/log/macscope-vhid-install.log | grep "\[stage"

# 2. Verify driver
systemextensionsctl list | grep Karabiner
# Expect: [activated enabled]

# 3. Verify daemon
pgrep -x "Karabiner-VirtualHIDDevice-Daemon"
# Expect: PID number

# 4. Verify relay daemon
sudo launchctl print system/com.macscope.vhid.relay | grep state
# Expect: state = running

# 5. Check logs
sudo tail -20 /var/log/macscope-vhid.log
# Expect: "VirtualHID relay listening on /tmp/macs_vhid_*.sock"
```

---

**Status:** ✅ Sequential blocking implemented  
**Last Updated:** January 21, 2025
