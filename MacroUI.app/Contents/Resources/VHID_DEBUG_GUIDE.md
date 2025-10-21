# 🔧 VirtualHID Integration and Debugging Guide

## ✅ Integration Status

Your VirtualHID system is now properly integrated into MacScope:

### UI Integration
- ✅ VirtualHID Manager accessible via sidebar in main app
- ✅ Separate window available with ⌘⇧V keyboard shortcut  
- ✅ Menu item added to Window menu

### Code Integration
- ✅ All VHIDCommands now use consistent Karabiner JSON protocol
- ✅ Proper BSD socket communication in VHIDCore.swift
- ✅ Consolidated type definitions to avoid conflicts

## 🚨 Command Execution Issues

Your commands now send **Karabiner-compatible JSON**:

### Mouse Commands:
```json
{"type":"pointing_input","x":50,"y":0,"vertical_wheel":0,"horizontal_wheel":0,"buttons":0}
```

### Keyboard Commands:
```json  
{"type":"keyboard_input","modifiers":0,"keys":[4]}
```

### Ping Commands:
```json
{"id":1,"type":"ping"}
```

## 🔍 Debugging Steps

### 1. Test Socket Connection
```bash
# Check if socket exists
ls -la /tmp/macs_vhid_$(id -u).sock

# Test raw socket connection
echo '{"id":1,"type":"ping"}' | nc -U /tmp/macs_vhid_$(id -u).sock
```

### 2. Debug Your Relay Daemon
Your relay daemon at `/usr/local/bin/macscope-vhid` should:

1. **Listen** on Unix socket `/tmp/macs_vhid_$(uid).sock`
2. **Parse** incoming JSON commands
3. **Convert** them to VirtualHID driver calls
4. **Reply** with status

#### Check if relay is running:
```bash
ps aux | grep macscope-vhid
lsof | grep macs_vhid
```

### 3. Command Flow Debugging

**Expected Flow:**
```
MacScope App → JSON Command → Unix Socket → Relay Daemon → VirtualHID Driver → System
```

**Use VirtualHID Manager diagnostics:**
1. Open VirtualHID Manager (⌘⇧V)
2. Click "Diagnostics" - this will check:
   - ✅ Karabiner daemon running?
   - ✅ Your relay daemon running? 
   - ✅ Socket exists and connectable?
   - ✅ Ping response working?

### 4. Test Individual Components

#### Test JSON Commands:
The app now sends these exact JSON formats - verify your relay daemon expects them:

```bash
# Test mouse move
echo '{"type":"pointing_input","x":10,"y":10,"vertical_wheel":0,"horizontal_wheel":0,"buttons":0}' | nc -U /tmp/macs_vhid_$(id -u).sock

# Test mouse click  
echo '{"type":"pointing_input","x":0,"y":0,"vertical_wheel":0,"horizontal_wheel":0,"buttons":1}' | nc -U /tmp/macs_vhid_$(id -u).sock

# Test key press (key 'a' = HID usage 0x04)
echo '{"type":"keyboard_input","modifiers":0,"keys":[4]}' | nc -U /tmp/macs_vhid_$(id -u).sock
```

## 🎯 Most Likely Issues

### 1. Relay Daemon Protocol Mismatch
Your relay might expect a different JSON format. Check if it's expecting:
- Custom format vs Karabiner format
- Different field names
- Additional wrapper objects

### 2. Permissions Issues  
```bash
# Check relay daemon permissions
ls -la /usr/local/bin/macscope-vhid
sudo /usr/local/bin/macscope-vhid --test  # If it has test mode
```

### 3. VirtualHID Driver Issues
```bash
# Check if Karabiner VirtualHIDDevice is loaded
kextstat | grep pqrs
system_profiler SPUSBDataType | grep -i virtual
```

## 🔧 Quick Fixes to Try

### 1. Restart VirtualHID Stack
Use the "Start vHID Stack" button in VirtualHID Manager

### 2. Manual Relay Restart
```bash
sudo pkill macscope-vhid
sudo /usr/local/bin/macscope-vhid
```

### 3. Check System Permissions
Make sure your app has:
- Accessibility permissions
- Input Monitoring permissions  

## 📊 Using Built-in Diagnostics

Your VirtualHID Manager has comprehensive logging:

1. **Status Lights** show real-time component status
2. **Log Console** shows all commands and responses  
3. **Test Buttons** let you verify each component:
   - Move Mouse - tests mouse movement
   - Press Key - tests keyboard input
   - Ping - tests socket communication

## 🎪 Testing Protocol

1. **Open VirtualHID Manager** (⌘⇧V or sidebar)
2. **Start vHID Stack** if not running
3. **Run Diagnostics** - all should be green
4. **Test Mouse Move** - check logs for command/response
5. **Test Key Press** - verify keyboard commands work

If ping works but mouse/keyboard don't, the issue is in your relay daemon's command parsing or VirtualHID driver communication.

## 🆘 Next Steps

Share the VirtualHID Manager log output when you:
1. Click "Diagnostics"
2. Try "Test Mouse Move" 
3. Try "Test Key Press"

This will show exactly where the command flow breaks!