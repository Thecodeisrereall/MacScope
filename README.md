# MacScope VirtualHID Installer

> Automated installer for MacScope VirtualHID relay daemon with Karabiner-DriverKit integration

## 🎯 Overview

This repository contains the installation scripts and build tools for the MacScope VirtualHID relay system. The relay daemon enables communication between user-space applications and the Karabiner-DriverKit-VirtualHIDDevice kernel extension, providing programmatic control over virtual keyboard and mouse input.

## ✨ Features

- **One-line installer**: Simple curl command for quick setup
- **Automatic driver detection**: Checks for Karabiner VirtualHID driver
- **LaunchDaemon integration**: Runs as system service with automatic restart
- **UNIX socket IPC**: Per-user socket communication for security
- **Comprehensive logging**: All operations logged to `/var/log/macscope-vhid.log`

## 📋 Requirements

- macOS 13.0 (Ventura) or later
- Karabiner-DriverKit-VirtualHIDDevice v6.4.0+ (auto-installed if missing)
- Administrator privileges (sudo access)

## 🚀 Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/macscope-install/main/scripts/install_vhid_relay.sh | sudo bash
```

## 📦 Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/macscope-install.git
cd macscope-install

# Run installer
sudo ./scripts/install_vhid_relay.sh
```

## 🔧 What Gets Installed

| Component | Location | Purpose |
|-----------|----------|---------|
| Relay Binary | `/usr/local/bin/macscope-vhid` | Main relay daemon |
| LaunchDaemon | `/Library/LaunchDaemons/com.macscope.vhid.relay.plist` | Service configuration |
| Socket | `/tmp/macs_vhid_${UID}.sock` | IPC endpoint per user |
| Logs | `/var/log/macscope-vhid.log` | Service logs |

## 📖 Usage

After installation, the relay daemon runs automatically. Applications communicate via the UNIX socket:

```bash
# Check daemon status
sudo launchctl list | grep macscope

# View logs
tail -f /var/log/macscope-vhid.log

# Test socket connection
echo '{"type":"ping"}' | nc -U /tmp/macs_vhid_${UID}.sock
```

## 🛠️ Development

```bash
# Build from source
cd build
./build.sh

# Run tests
cd tests
./run_tests.sh
```

## 🗑️ Uninstallation

```bash
sudo launchctl unload /Library/LaunchDaemons/com.macscope.vhid.relay.plist
sudo rm /Library/LaunchDaemons/com.macscope.vhid.relay.plist
sudo rm /usr/local/bin/macscope-vhid
rm /tmp/macs_vhid_*.sock
```

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.

## 🐛 Issues & Support

Report issues at: https://github.com/yourusername/macscope-install/issues

## 📚 Documentation

- [Installation Guide](docs/INSTALL.md)
- [API Documentation](docs/API.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

---

**Built with ❤️ for the MacScope project**
