# VirtualHID Installer Integration Guide

## Files Added:
1. `VHIDInstallerView.swift` - The installer UI view
2. `install_vhid_relay.sh` - Installation script

## Integration Steps:

### 1. Add the installer script to your project bundle:
- In Xcode, add the `install_vhid_relay.sh` file to your project
- Make sure it's added to the target's "Copy Bundle Resources" build phase
- This allows the installer to find the script via `Bundle.main.path(forResource:ofType:)`

### 2. Update Info.plist for AppleScript permissions:
Add these keys to your app's Info.plist file:

```xml
<key>NSAppleEventsUsageDescription</key>
<string>MacScope needs to run administrative scripts to install the VirtualHID system components.</string>
```

### 3. Make the installation script executable:
In your project directory, run:
```bash
chmod +x install_vhid_relay.sh
```

## Current Integration:
- ✅ The `VHIDInstallerView` is already integrated into `VHIDManagerView` as Tab 0
- ✅ The existing manager and testing tools are on Tab 1
- ✅ Navigation from the main ContentView is already set up
- ✅ The installer can be accessed via the "vHID Manager" menu item or Cmd+Shift+V

## Features:
- **Status Indicators**: Shows real-time status of driver, daemon, and socket
- **One-Click Install**: Prompts for admin password and installs everything
- **Restart Function**: Can restart the daemon if needed
- **Uninstall Function**: Clean removal of all components
- **Live Logs**: Shows installation progress and any errors
- **Error Handling**: Graceful error handling with user feedback

## Usage:
1. User goes to VirtualHID Manager (either from sidebar or window menu)
2. The "Installer" tab is selected by default (tab 0)
3. User sees status indicators (initially red for "Not Installed")
4. User clicks "Install VirtualHID System"
5. macOS prompts for admin password
6. Installation runs and logs are shown in real-time
7. Status indicators turn green when complete
8. User can then switch to "Manager & Testing" tab to use HID functions

## What the installer does:
1. Downloads and installs Karabiner-DriverKit-VirtualHIDDevice driver
2. Creates a Python-based relay daemon that communicates with the driver
3. Sets up a launchd service to run the daemon automatically
4. Creates Unix socket for communication with MacScope
5. Verifies the installation and provides feedback

## Notes:
- The user may need to approve the system extension in System Settings > Privacy & Security
- The installer handles this gracefully and provides instructions
- All components can be cleanly uninstalled using the uninstall button
- The system works across reboots once installed