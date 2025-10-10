#!/bin/bash
# dependencies.sh — verify minimal toolchain; do not auto-install Homebrew
set -euo pipefail

# Standard PATH setup
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

LOGFILE="/var/log/macscope-vhid/dependencies.log"

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ 
  local msg="$*"
  printf "%s [MacScope] %s\n" "$(ts)" "$msg"
  if [[ -w "$(dirname "$LOGFILE")" || ! -e "$LOGFILE" ]]; then
    printf "%s [MacScope] %s\n" "$(ts)" "$msg" >> "$LOGFILE" 2>/dev/null || true
  fi
}
warn(){ 
  local msg="$*"
  printf "%s [MacScope] [WARN] %s\n" "$(ts)" "$msg" >&2
  if [[ -w "$(dirname "$LOGFILE")" || ! -e "$LOGFILE" ]]; then
    printf "%s [MacScope] [WARN] %s\n" "$(ts)" "$msg" >> "$LOGFILE" 2>/dev/null || true
  fi
}
err(){ 
  local msg="$*"
  printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$msg" >&2
  if [[ -w "$(dirname "$LOGFILE")" || ! -e "$LOGFILE" ]]; then
    printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$msg" >> "$LOGFILE" 2>/dev/null || true
  fi
}

declare -A cmds=(
  [clang++]=0
  [git]=0
  [brew]=0
  [osascript]=0
  [launchctl]=0
)

# Require Command Line Tools (clang++) and git
if command -v clang++ >/dev/null 2>&1; then
  cmds[clang++]=1
else
  err "Xcode Command Line Tools (clang++) not found. Open Terminal and run: xcode-select --install"
  exit 1
fi

if command -v git >/dev/null 2>&1; then
  cmds[git]=1
else
  err "git not found. Install Xcode Command Line Tools or git (e.g. via Homebrew)."
  exit 1
fi

# Optional developer conveniences
if command -v brew >/dev/null 2>&1; then
  cmds[brew]=1
else
  warn "Homebrew not found (optional). Skipping."
fi

# Check for osascript (AppleScript) availability
if command -v osascript >/dev/null 2>&1; then
  cmds[osascript]=1
else
  warn "osascript not found (optional). Some admin automation features may be unavailable."
fi

# Check for launchctl availability
if command -v launchctl >/dev/null 2>&1; then
  cmds[launchctl]=1
else
  warn "launchctl not found (optional). Some admin automation features may be unavailable."
fi

log "All dependencies satisfied ✅"

# Verbose summary
log "Dependency summary:"
for cmd in "${!cmds[@]}"; do
  if [[ ${cmds[$cmd]} -eq 1 ]]; then
    log "  - $cmd: found"
  else
    log "  - $cmd: missing"
  fi
done
