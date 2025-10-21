#!/bin/bash

# MacScope VirtualHID Relay Installer
# Installs relay daemon and Karabiner driver with proper permissions

set -euo pipefail

###################
# Configuration
###################

readonly RELAY_BIN="/usr/local/bin/macscope-vhid"
readonly PLIST_PATH="/Library/LaunchDaemons/com.macscope.vhid.relay.plist"
readonly LOG_FILE="/var/log/macscope-vhid-install.log"
readonly DRIVER_VERSION="6.4.0"
readonly DRIVER_URL="https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v${DRIVER_VERSION}/Karabiner-DriverKit-VirtualHIDDevice-${DRIVER_VERSION}.pkg"
readonly SOCKET_DIR="/tmp"

###################
# Colors
###################

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

###################
# Logging
###################

log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    log "INFO" "$*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
    log "SUCCESS" "$*"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*"
    log "WARNING" "$*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
    log "ERROR" "$*"
}

log_step() {
    echo -e "${CYAN}[→]${NC} $*"
    log "STEP" "$*"
}

###################
# Pre-flight Checks
###################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_macos_version() {
    local version
    version=$(sw_vers -productVersion)
    local major
    major=$(echo "$version" | cut -d. -f1)
    
    if [[ $major -lt 13 ]]; then
        log_error "macOS 13.0 (Ventura) or later required. Found: $version"
        exit 1
    fi
    
    log_info "macOS version: $version ✓"
}

get_real_user() {
    # Get the actual user who ran sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        stat -f '%Su' /dev/console
    fi
}

###################
# Driver Management
###################

check_driver() {
    log_step "Checking for Karabiner VirtualHID driver..."
    
    if systemextensionsctl list 2>/dev/null | grep -q "Karabiner-DriverKit-VirtualHIDDevice"; then
        local status
        status=$(systemextensionsctl list 2>/dev/null | grep "Karabiner-DriverKit-VirtualHIDDevice")
        
        if echo "$status" | grep -q "\[activated enabled\]"; then
            log_success "Driver found and activated"
            return 0
        else
            log_warning "Driver found but not fully activated"
            log_warning "Status: $status"
            return 1
        fi
    else
        log_warning "Driver not found"
        return 1
    fi
}

install_driver() {
    log_step "Installing Karabiner VirtualHID driver v${DRIVER_VERSION}..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    local pkg_path="$temp_dir/driver.pkg"
    
    log_info "Downloading driver..."
    if ! curl -L -s -o "$pkg_path" "$DRIVER_URL"; then
        log_error "Failed to download driver"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_info "Installing driver package..."
    if ! installer -pkg "$pkg_path" -target / &>> "$LOG_FILE"; then
        log_error "Failed to install driver"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    rm -rf "$temp_dir"
    log_success "Driver installed"
    
    log_warning ""
    log_warning "═══════════════════════════════════════════════════"
    log_warning "  ACTION REQUIRED: Approve System Extension"
    log_warning "═══════════════════════════════════════════════════"
    log_warning ""
    log_warning "1. Open System Settings → Privacy & Security"
    log_warning "2. Click 'Allow' for the Karabiner driver"
    log_warning "3. Restart your Mac"
    log_warning ""
    log_warning "After reboot, run this installer again to complete setup."
    log_warning ""
    
    exit 0
}

###################
# Binary Management
###################

check_binary() {
    local binary_path="$1"
    
    if [[ ! -f "$binary_path" ]]; then
        log_error "Binary not found: $binary_path"
        return 1
    fi
    
    if [[ ! -x "$binary_path" ]]; then
        log_error "Binary not executable: $binary_path"
        return 1
    fi
    
    # Verify it's a Mach-O binary
    if ! file "$binary_path" | grep -q "Mach-O"; then
        log_error "Not a valid Mach-O binary: $binary_path"
        return 1
    fi
    
    return 0
}

install_binary() {
    local source_path="$1"
    
    log_step "Installing relay binary..."
    
    if ! check_binary "$source_path"; then
        log_error "Source binary validation failed"
        exit 1
    fi
    
    # Backup existing binary if present
    if [[ -f "$RELAY_BIN" ]]; then
        local backup_path="${RELAY_BIN}.backup.$(date +%s)"
        log_info "Backing up existing binary to: $backup_path"
        cp "$RELAY_BIN" "$backup_path"
    fi
    
    # Copy binary
    cp "$source_path" "$RELAY_BIN"
    
    # Set permissions
    chown root:wheel "$RELAY_BIN"
    chmod 755 "$RELAY_BIN"
    
    log_success "Binary installed at: $RELAY_BIN"
}

###################
# LaunchDaemon Management
###################

stop_daemon() {
    log_step "Stopping existing daemon..."
    
    if launchctl list | grep -q "com.macscope.vhid.relay"; then
        launchctl bootout system "$PLIST_PATH" 2>/dev/null || true
        sleep 1
        log_success "Daemon stopped"
    else
        log_info "Daemon not running"
    fi
}

create_plist() {
    log_step "Creating LaunchDaemon plist..."
    
    cat > "$PLIST_PATH" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.macscope.vhid.relay</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/macscope-vhid</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>/var/log/macscope-vhid.log</string>
    
    <key>StandardErrorPath</key>
    <string>/var/log/macscope-vhid.log</string>
    
    <key>ThrottleInterval</key>
    <integer>5</integer>
    
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF
    
    chown root:wheel "$PLIST_PATH"
    chmod 644 "$PLIST_PATH"
    
    log_success "LaunchDaemon plist created"
}

start_daemon() {
    log_step "Starting daemon..."
    
    if launchctl bootstrap system "$PLIST_PATH" 2>> "$LOG_FILE"; then
        sleep 2
        
        if launchctl list | grep -q "com.macscope.vhid.relay"; then
            log_success "Daemon started successfully"
            return 0
        else
            log_error "Daemon failed to start"
            return 1
        fi
    else
        log_error "Failed to bootstrap daemon"
        return 1
    fi
}

###################
# Verification
###################

verify_socket() {
    log_step "Verifying socket creation..."
    
    local real_user
    real_user=$(get_real_user)
    local real_uid
    real_uid=$(id -u "$real_user")
    
    local socket_path="${SOCKET_DIR}/macs_vhid_${real_uid}.sock"
    local max_wait=10
    local waited=0
    
    while [[ $waited -lt $max_wait ]]; do
        if [[ -S "$socket_path" ]]; then
            log_success "Socket created: $socket_path"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    
    log_warning "Socket not found after ${max_wait}s: $socket_path"
    log_info "Check logs: tail -f /var/log/macscope-vhid.log"
    return 1
}

verify_installation() {
    log_step "Running final verification..."
    
    local errors=0
    
    # Check binary
    if [[ -f "$RELAY_BIN" ]] && [[ -x "$RELAY_BIN" ]]; then
        log_success "Binary present and executable"
    else
        log_error "Binary check failed"
        errors=$((errors + 1))
    fi
    
    # Check plist
    if [[ -f "$PLIST_PATH" ]]; then
        log_success "LaunchDaemon plist present"
    else
        log_error "LaunchDaemon plist missing"
        errors=$((errors + 1))
    fi
    
    # Check daemon status
    if launchctl list | grep -q "com.macscope.vhid.relay"; then
        log_success "Daemon is running"
    else
        log_error "Daemon is not running"
        errors=$((errors + 1))
    fi
    
    # Check socket
    verify_socket || errors=$((errors + 1))
    
    if [[ $errors -eq 0 ]]; then
        log_success "All verification checks passed!"
        return 0
    else
        log_error "$errors verification check(s) failed"
        return 1
    fi
}

###################
# Main Installation
###################

print_banner() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║                                                  ║"
    echo "║       MacScope VirtualHID Relay Installer       ║"
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
}

print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Installation Summary"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Binary:        $RELAY_BIN"
    echo "LaunchDaemon:  $PLIST_PATH"
    echo "Logs:          /var/log/macscope-vhid.log"
    echo "Socket:        ${SOCKET_DIR}/macs_vhid_\${UID}.sock"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo ""
}

main() {
    print_banner
    
    # Initialize log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    log_info "Starting installation at $(date)"
    
    # Pre-flight checks
    check_root
    check_macos_version
    
    # Check/install driver
    if ! check_driver; then
        install_driver
        # Script exits here with instructions
    fi
    
    # Find binary
    local binary_source
    if [[ -f "./payload/macscope-vhid" ]]; then
        binary_source="./payload/macscope-vhid"
    elif [[ -f "./macscope-vhid" ]]; then
        binary_source="./macscope-vhid"
    elif [[ -f "../build/Release/macscope-vhid" ]]; then
        binary_source="../build/Release/macscope-vhid"
    else
        log_error "Cannot find macscope-vhid binary"
        log_info "Expected locations:"
        log_info "  - ./payload/macscope-vhid"
        log_info "  - ./macscope-vhid"
        log_info "  - ../build/Release/macscope-vhid"
        exit 1
    fi
    
    log_info "Using binary: $binary_source"
    
    # Stop existing daemon
    stop_daemon
    
    # Install components
    install_binary "$binary_source"
    create_plist
    
    # Start and verify
    if start_daemon; then
        if verify_installation; then
            print_summary
            log_success "Installation completed successfully!"
            echo ""
            echo "🎉 MacScope VirtualHID relay is now running!"
            echo ""
            echo "Quick test:"
            echo "  echo '{\"type\":\"ping\"}' | nc -U ${SOCKET_DIR}/macs_vhid_\$(id -u).sock"
            echo ""
            exit 0
        else
            log_error "Installation verification failed"
            exit 1
        fi
    else
        log_error "Failed to start daemon"
        log_info "Check logs: tail -f /var/log/macscope-vhid.log"
        exit 1
    fi
}

# Run main installation
main "$@"
