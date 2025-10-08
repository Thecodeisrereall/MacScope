# MacScope vHID Kit

MacScope is a hybrid VirtualHID automation toolkit for macOS built on top of [Karabiner-DriverKit-VirtualHIDDevice 6.3.0](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice).

## Structure
- **Scripts/** – shell utilities for building and managing the vHID environment
- **Source/** – Swift source files for MacScope.app and CLI tester
- **Docs/** – logging, troubleshooting, and developer notes

## Installing the Scripts
The app or terminal tool will automatically check for `~/Library/MacScope_vHID_Kit`.
If missing, you can manually run:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Thecodeisrereall/MacScope/main/Scripts/MacScope_Setup_vHID_Kit.sh)
