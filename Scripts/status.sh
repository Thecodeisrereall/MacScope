#!/bin/bash
# status.sh — friendly status, no hard failure if ping requires sudo
set -euo pipefail

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
say(){ printf "%s\n" "$*"; }

MAN="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
DAE="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
BIN="/usr/local/bin/macscope-vhid"
SOCK_DIR="/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"

echo "=== MacScope vHID Status ==="
if [[ -x "$MAN" ]]; then say "- Manager: $MAN OK"; else say "- Manager: MISSING ($MAN)"; fi
if [[ -x "$DAE" ]]; then say "- Daemon : $DAE  OK"; else say "- Daemon : MISSING ($DAE)"; fi
if pgrep -fl "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
  say "- Daemon process: RUNNING"
else
  say "- Daemon process: STOPPED"
fi

if [[ -x "$BIN" ]]; then
  if sudo -n "$BIN" ping >/dev/null 2>&1; then
    say "- macscope-vhid: PRESENT ($BIN)"
    say "- macscope-vhid ping: OK"
  else
    say "- macscope-vhid: PRESENT ($BIN)"
    if sudo "$BIN" ping >/dev/null 2>&1; then
      say "- macscope-vhid ping: OK"
    else
      say "- macscope-vhid ping: FAILED"
    fi
  fi
else
  say "- macscope-vhid: MISSING"
fi
