#!/bin/bash
# restart.sh — restart daemon (root), re-activate manager
set -euo pipefail

# Setup PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOG_DIR="/var/log/macscope-vhid"
LOG_FILE="$LOG_DIR/restart.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){
    local msg="$*"
    printf "%s [MacScope] %s\n" "$(ts)" "$msg" | tee -a "$LOG_FILE"
}
die(){
    local msg="$*"
    printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$msg" | tee -a "$LOG_FILE" >&2
    exit 1
}

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run with administrator privileges."

MAN="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
DAE="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"

# Check binaries exist and are executable
[[ -x "$MAN" ]] || die "Manager binary not found or not executable at $MAN"
[[ -x "$DAE" ]] || die "Daemon binary not found or not executable at $DAE"

log "Stopping daemon (if running)…"
if pkill -f "Karabiner-VirtualHIDDevice-Daemon"; then
    # Wait for daemon to fully exit
    for i in {1..10}; do
        if ! pgrep -f "Karabiner-VirtualHIDDevice-Daemon" >/dev/null; then
            break
        fi
        sleep 0.5
    done
    if pgrep -f "Karabiner-VirtualHIDDevice-Daemon" >/dev/null; then
        die "Failed to stop existing daemon process."
    fi
    log "Daemon stopped successfully."
else
    log "No daemon process found running."
fi

log "Re-activating Manager…"
if [[ -x "$MAN" ]]; then
    if "$MAN" activate; then
        log "Manager re-activated successfully."
    else
        die "Manager activation failed."
    fi
else
    die "Manager binary not executable at $MAN"
fi

log "Starting daemon…"
if nohup "$DAE" >/dev/null 2>&1 & disown; then
    # Wait for daemon to start
    for i in {1..10}; do
        if pgrep -f "Karabiner-VirtualHIDDevice-Daemon" >/dev/null; then
            log "Daemon started successfully."
            log "Restart complete ✅"
            exit 0
        fi
        sleep 0.5
    done
    die "Daemon failed to start within expected time."
else
    die "Failed to launch daemon."
fi

