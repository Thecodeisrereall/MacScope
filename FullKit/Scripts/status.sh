#!/bin/bash
# status.sh — friendly status, no hard failure if ping requires sudo
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

LOGFILE="/var/log/macscope-vhid/status.log"

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
say(){
  local msg="$*"
  printf "%s %s\n" "$(ts)" "$msg" | tee -a "$LOGFILE"
}

MAN="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
DAE="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
BIN="/usr/local/bin/macscope-vhid"
RELAY="/usr/local/bin/vhidrelay"
SOCK_DIR="/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"

say "=== MacScope vHID Status ==="

status_ok=true
status_degraded=false

if [[ -x "$MAN" ]]; then
  say "- Manager: $MAN OK"
else
  say "- Manager: MISSING ($MAN)"
  status_ok=false
fi

if [[ -x "$DAE" ]]; then
  say "- Daemon : $DAE OK"
else
  say "- Daemon : MISSING ($DAE)"
  status_ok=false
fi

if pgrep -fl "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
  say "- Daemon process: RUNNING"
else
  say "- Daemon process: STOPPED"
  status_ok=false
fi

if [[ -x "$BIN" ]]; then
  say "- macscope-vhid: PRESENT ($BIN)"
  if sudo -n "$BIN" ping >/dev/null 2>&1; then
    say "- macscope-vhid ping: OK"
  else
    if sudo "$BIN" ping >/dev/null 2>&1; then
      say "- macscope-vhid ping: OK"
      status_degraded=true
    else
      say "- macscope-vhid ping: FAILED"
      status_ok=false
    fi
  fi
else
  say "- macscope-vhid: MISSING"
  status_ok=false
fi

if [[ -x "$RELAY" ]]; then
  say "- vhidrelay: PRESENT ($RELAY)"
else
  say "- vhidrelay: MISSING"
  status_ok=false
fi

# Summary of overall vHID health
if $status_ok; then
  say "=== vHID Health Summary: OK ==="
elif $status_degraded; then
  say "=== vHID Health Summary: DEGRADED ==="
else
  say "=== vHID Health Summary: ERROR ==="
fi
