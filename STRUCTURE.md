# Repository Structure

Complete overview of the MacScope installer repository.

## 📁 Directory Structure

```
macscope/
├── README.md                    # Main repository documentation
├── LICENSE                      # MIT License
├── .gitignore                   # Git ignore rules
├── CONTRIBUTING.md              # Contribution guidelines
├── QUICKSTART.md               # Quick start guide
├── setup.sh                    # GitHub repository setup script
│
├── scripts/                    # Installation scripts
│   ├── install_vhid_relay.sh  # Main installer (can run standalone)
│   ├── preinstall              # Package preinstall script
│   └── postinstall             # Package postinstall script
│
├── build/                      # Build system
│   └── build.sh                # Package builder script
│
├── payload/                    # Installation payload
│   ├── README.md               # Payload instructions
│   ├── macscope-vhid           # Binary (excluded from git, add yours)
│   └── com.macscope.vhid.relay.plist  # LaunchDaemon config
│
└── docs/                       # Documentation
    ├── INSTALL.md              # Detailed installation guide
    └── TROUBLESHOOTING.md      # Troubleshooting guide
```

## 📄 File Descriptions

### Root Level

**README.md**
- Project overview and quick links
- Installation options (one-line, manual, package)
- Usage examples
- Links to documentation

**LICENSE**
- MIT License for the project

**.gitignore**
- Excludes binaries, build artifacts, logs
- Keeps repository clean

**CONTRIBUTING.md**
- Contribution guidelines
- Code standards
- Commit message format
- Pull request process

**QUICKSTART.md**
- 5-minute setup guide
- Quick verification steps
- Common use cases in multiple languages

**setup.sh**
- Initializes git repository
- Creates GitHub remote
- Pushes initial commit
- Usage: `./setup.sh <github-username>`

### scripts/

**install_vhid_relay.sh** (Main installer)
- Checks system requirements (macOS 13+)
- Verifies/installs Karabiner driver
- Installs relay binary
- Creates LaunchDaemon
- Starts and verifies daemon
- Comprehensive logging
- Can run standalone or as part of package

**preinstall**
- Stops existing daemon
- Cleans up old sockets
- Backs up existing binary
- Called before package installation

**postinstall**
- Sets file permissions
- Starts daemon
- Verifies socket creation
- Called after package installation

### build/

**build.sh**
- Validates binary presence
- Creates package directory structure
- Copies payload and scripts
- Builds .pkg with `pkgbuild`
- Outputs to ~/Desktop/MacScope_VirtualHID_Installer.pkg

### payload/

**README.md**
- Instructions for adding your binary
- Binary requirements
- Verification steps

**macscope-vhid**
- Your compiled relay binary
- Not included in git (you add it)
- Must be Mach-O executable

**com.macscope.vhid.relay.plist**
- LaunchDaemon configuration
- Auto-restart on crash
- Logging configuration
- Throttle interval

### docs/

**INSTALL.md**
- Prerequisites
- Detailed installation steps
- Building from source
- Verification procedures
- Uninstallation

**TROUBLESHOOTING.md**
- Common issues and solutions
- Log analysis guide
- System diagnostics
- Driver issues
- Permission problems

## 🚀 Usage Scenarios

### Scenario 1: End User Installation

User receives .pkg file:
```bash
sudo installer -pkg MacScope_VirtualHID_Installer.pkg -target /
```

### Scenario 2: Developer Testing

Developer has source:
```bash
cd ~/Documents/github/macscope
cp /path/to/binary ./payload/macscope-vhid
sudo ./scripts/install_vhid_relay.sh
```

### Scenario 3: Building Distribution Package

Creating .pkg for others:
```bash
cd ~/Documents/github/macscope
cp /path/to/binary ./payload/macscope-vhid
cd build
./build.sh
# Package created at ~/Desktop/MacScope_VirtualHID_Installer.pkg
```

### Scenario 4: Quick Remote Install

One-line installer (after pushing to GitHub):
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/macscope-install/main/scripts/install_vhid_relay.sh | sudo bash
```

## 🔧 Customization Points

### Change Binary Name
Edit in:
- `scripts/install_vhid_relay.sh` (RELAY_BIN)
- `payload/com.macscope.vhid.relay.plist` (ProgramArguments)

### Change LaunchDaemon Label
Edit in:
- `scripts/install_vhid_relay.sh` (PLIST_PATH)
- `payload/com.macscope.vhid.relay.plist` (Label)
- `scripts/preinstall`
- `scripts/postinstall`

### Change Socket Location
Edit in:
- `scripts/install_vhid_relay.sh` (SOCKET_DIR)
- Your relay binary source code

### Change Log Location
Edit in:
- `payload/com.macscope.vhid.relay.plist` (StandardOutPath/StandardErrorPath)
- Documentation files

## 📦 Installation Flow

### Package Installation

```
1. User runs: sudo installer -pkg ... -target /
   ↓
2. preinstall runs:
   - Stops existing daemon
   - Cleans up sockets
   - Backs up old binary
   ↓
3. Payload installed:
   - Binary → /usr/local/bin/macscope-vhid
   - Plist → /Library/LaunchDaemons/com.macscope.vhid.relay.plist
   ↓
4. postinstall runs:
   - Sets permissions
   - Starts daemon
   - Verifies socket
   ↓
5. Daemon running!
```

### Script Installation

```
1. User runs: sudo ./scripts/install_vhid_relay.sh
   ↓
2. Check system requirements
   ↓
3. Check/install driver
   ↓
4. Stop existing daemon
   ↓
5. Install binary
   ↓
6. Create plist
   ↓
7. Start daemon
   ↓
8. Verify installation
   ↓
9. Done!
```

## 🔒 Security Considerations

### File Permissions
- Binary: `755` (root:wheel)
- Plist: `644` (root:wheel)
- Logs: `644` (readable by all)

### Socket Permissions
- Per-user sockets: `/tmp/macs_vhid_${UID}.sock`
- Only owner can access their socket

### Code Signing
- Binary should be signed for distribution
- Package should be signed for notarization
- Add signing in `build.sh` if needed

## 🧪 Testing Checklist

Before release:
- [ ] Test on clean macOS 13.0 install
- [ ] Test on macOS 14.0+
- [ ] Test with existing installation
- [ ] Test preinstall script
- [ ] Test postinstall script
- [ ] Test uninstall procedure
- [ ] Verify all log files created
- [ ] Test socket communication
- [ ] Test driver interaction
- [ ] Verify permissions correct
- [ ] Test on both Intel and Apple Silicon

## 📝 Next Steps

1. **Add your binary:**
   ```bash
   cp /path/to/macscope-vhid payload/
   ```

2. **Initialize git repository:**
   ```bash
   ./setup.sh your-github-username
   ```

3. **Build and test:**
   ```bash
   cd build
   ./build.sh
   sudo installer -pkg ~/Desktop/MacScope_VirtualHID_Installer.pkg -target /
   ```

4. **Verify installation:**
   ```bash
   sudo launchctl list | grep macscope
   echo '{"type":"ping"}' | nc -U /tmp/macs_vhid_$(id -u).sock
   ```

5. **Push to GitHub:**
   ```bash
   git add payload/macscope-vhid
   git commit -m "Add compiled binary"
   git push
   ```

---

**Repository ready for development and distribution! 🎉**
