#!/bin/bash
# start_daemon.sh — start the Karabiner VirtualHIDDevice daemon (requires admin)
set -euo pipefail

LOGFILE="/var/log/macscope-vhid/start_daemon.log"
mkdir -p "$(dirname "$LOGFILE")"

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*" | tee -a "$LOGFILE"; }
die(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" | tee -a "$LOGFILE" >&2; exit 1; }

# Set PATH to include standard system paths
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

DAE="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  # Try non-interactive sudo first
  if sudo -n true 2>/dev/null; then
    exec sudo "$0" "$@"
  else
    die "Please run with administrator privileges (e.g. via bringup.sh)."
  fi
fi

if [[ ! -e "$DAE" ]]; then
  die "Daemon binary not found at '$DAE'."
fi

if [[ ! -x "$DAE" ]]; then
  die "Daemon binary at '$DAE' is not executable."
fi

if pgrep -fl "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
  log "Daemon already running."
  exit 0
else
  log "Starting daemon…"
  nohup "$DAE" >/dev/null 2>&1 & disown || die "Failed to launch daemon."

  # Wait up to 5 seconds for the daemon to start
  for i in {1..5}; do
    sleep 1
    if pgrep -fl "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
      log "Daemon started successfully."
      exit 0
    fi
  done

  die "Daemon failed to start within 5 seconds."
fi
