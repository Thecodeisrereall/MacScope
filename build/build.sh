#!/bin/bash

# Build script for MacScope VirtualHID installer package
# Creates a .pkg installer from the repository contents

set -euo pipefail

###################
# Configuration
###################

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly REPO_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BUILD_DIR="$REPO_ROOT/build"
readonly PAYLOAD_DIR="$REPO_ROOT/payload"
readonly SCRIPTS_DIR="$REPO_ROOT/scripts"
readonly PKG_NAME="MacScope_VirtualHID_Installer.pkg"
readonly OUTPUT_PATH="$HOME/Desktop/$PKG_NAME"

###################
# Colors
###################

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

###################
# Functions
###################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

log_step() {
    echo -e "${CYAN}[→]${NC} $*"
}

cleanup() {
    if [[ -d "$BUILD_DIR/root" ]]; then
        rm -rf "$BUILD_DIR/root"
    fi
    if [[ -d "$BUILD_DIR/scripts" ]]; then
        rm -rf "$BUILD_DIR/scripts"
    fi
}

check_requirements() {
    log_step "Checking requirements..."
    
    # Check for binary
    if [[ ! -f "$PAYLOAD_DIR/macscope-vhid" ]]; then
        log_error "Binary not found: $PAYLOAD_DIR/macscope-vhid"
        log_info "Copy your compiled binary to the payload directory first"
        exit 1
    fi
    
    # Verify binary is executable
    if [[ ! -x "$PAYLOAD_DIR/macscope-vhid" ]]; then
        log_error "Binary is not executable"
        chmod +x "$PAYLOAD_DIR/macscope-vhid"
        log_info "Fixed: made binary executable"
    fi
    
    # Check for plist
    if [[ ! -f "$PAYLOAD_DIR/com.macscope.vhid.relay.plist" ]]; then
        log_error "Plist not found: $PAYLOAD_DIR/com.macscope.vhid.relay.plist"
        exit 1
    fi
    
    log_success "All requirements met"
}

prepare_build_dir() {
    log_step "Preparing build directory..."
    
    mkdir -p "$BUILD_DIR"
    cleanup
    
    # Create root structure
    mkdir -p "$BUILD_DIR/root/usr/local/bin"
    mkdir -p "$BUILD_DIR/root/Library/LaunchDaemons"
    
    # Create scripts directory
    mkdir -p "$BUILD_DIR/scripts"
    
    log_success "Build directory prepared"
}

copy_payload() {
    log_step "Copying payload files..."
    
    # Copy binary
    cp "$PAYLOAD_DIR/macscope-vhid" "$BUILD_DIR/root/usr/local/bin/"
    chmod 755 "$BUILD_DIR/root/usr/local/bin/macscope-vhid"
    
    # Copy plist
    cp "$PAYLOAD_DIR/com.macscope.vhid.relay.plist" "$BUILD_DIR/root/Library/LaunchDaemons/"
    chmod 644 "$BUILD_DIR/root/Library/LaunchDaemons/com.macscope.vhid.relay.plist"
    
    log_success "Payload files copied"
}

copy_scripts() {
    log_step "Copying installation scripts..."
    
    if [[ -f "$SCRIPTS_DIR/preinstall" ]]; then
        cp "$SCRIPTS_DIR/preinstall" "$BUILD_DIR/scripts/"
        chmod +x "$BUILD_DIR/scripts/preinstall"
    fi
    
    if [[ -f "$SCRIPTS_DIR/postinstall" ]]; then
        cp "$SCRIPTS_DIR/postinstall" "$BUILD_DIR/scripts/"
        chmod +x "$BUILD_DIR/scripts/postinstall"
    fi
    
    log_success "Scripts copied"
}

build_package() {
    log_step "Building package..."
    
    local identifier="com.macscope.vhid.relay"
    local version="1.0.0"
    
    pkgbuild \
        --root "$BUILD_DIR/root" \
        --scripts "$BUILD_DIR/scripts" \
        --identifier "$identifier" \
        --version "$version" \
        --install-location "/" \
        "$OUTPUT_PATH"
    
    if [[ -f "$OUTPUT_PATH" ]]; then
        local size
        size=$(du -h "$OUTPUT_PATH" | cut -f1)
        log_success "Package built: $OUTPUT_PATH ($size)"
    else
        log_error "Package build failed"
        exit 1
    fi
}

print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Build Complete!"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Package: $OUTPUT_PATH"
    echo ""
    echo "To install:"
    echo "  sudo installer -pkg \"$OUTPUT_PATH\" -target /"
    echo ""
    echo "Or double-click the .pkg file to use GUI installer"
    echo ""
    echo "⚠️  Important: After installation, you may need to:"
    echo "  1. Approve system extension in System Settings"
    echo "  2. Restart your Mac"
    echo ""
}

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║                                                  ║"
    echo "║     MacScope VirtualHID Package Builder         ║"
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    
    check_requirements
    prepare_build_dir
    copy_payload
    copy_scripts
    build_package
    cleanup
    print_summary
    
    log_success "All done! 🎉"
}

# Handle cleanup on exit
trap cleanup EXIT

# Run main
main "$@"
