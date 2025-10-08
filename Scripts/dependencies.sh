#!/bin/bash
# dependencies.sh — verify/install prerequisites without running Homebrew as root.
set -euo pipefail
ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
warn(){ printf "%s [MacScope] [WARN] %s\n" "$(ts)" "$*" >&2; }
err(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; }
ASK_AUTO=no; [[ "${1:-}" == "-y" ]] && ASK_AUTO=yes
have(){ command -v "$1" >/dev/null 2>&1; }
confirm(){ local q="$1"; if [[ "$ASK_AUTO" == "yes" ]]; then return 0; fi; read -r -p "$q [y/N]: " ans; ans="${ans,,}"; [[ "$ans" == "y" || "$ans" == "yes" ]]; }

# 1) Xcode Command Line Tools
if ! have xcodebuild; then
  warn "Xcode Command Line Tools are missing."
  if confirm "Install Apple Command Line Tools now? (opens Apple GUI installer)"; then
    xcode-select --install || true
    log "Please complete the GUI installer, then re-run this script."
    exit 2
  else
    err "Command Line Tools required. Aborting."
    exit 1
  fi
fi

# 2) Homebrew (must NOT be installed as root)
if ! have brew; then
  warn "Homebrew not found."
  if confirm "Install Homebrew now?"; then
    if [[ -t 0 ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      /usr/bin/osascript <<'APPLESCRIPT'
tell application "Terminal"
  activate
  do script "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"; echo; echo 'Homebrew install finished (or check for prompts). You can close this window and return to MacScope.'"
end tell
APPLESCRIPT
      log "Opened Terminal to install Homebrew interactively. Re-run dependencies after it finishes."
      exit 2
    fi
    # Load brew shellenv for both Apple Silicon and Intel
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
  else
    err "Homebrew required for toolchain convenience. Aborting."
    exit 1
  fi
fi

# 3) Toolchain sanity
have git     || { err "git not found (expected in CLT)"; exit 1; }
have make    || { err "make not found (expected in CLT)"; exit 1; }
have clang++ || { err "clang++ not found (expected in CLT)"; exit 1; }

log "All dependencies satisfied ✅"
