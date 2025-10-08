#!/bin/bash
set -euo pipefail
ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
warn(){ printf "%s [MacScope] [WARN] %s\n" "$(ts)" "$*" >&2; }
err(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; }
ASK_AUTO=no; [[ "${1:-}" == "-y" ]] && ASK_AUTO=yes
have(){ command -v "$1" >/dev/null 2>&1; }
confirm(){ local q="$1"; if [[ "$ASK_AUTO" == "yes" ]]; then return 0; fi; read -r -p "$q [y/N]: " ans; ans="${ans,,}"; [[ "$ans" == "y" || "$ans" == "yes" ]]; }
if ! have xcodebuild; then warn "Xcode Command Line Tools are missing."; if confirm "Install Apple Command Line Tools now? (opens Apple GUI installer)"; then xcode-select --install || true; log "Complete the GUI installer, then re-run."; exit 2; else err "Command Line Tools required. Aborting."; exit 1; fi; fi
if ! have brew; then warn "Homebrew not found."; if confirm "Install Homebrew now?"; then /usr/bin/osascript -e 'do shell script "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" " with administrator privileges' || { err "Homebrew install failed or cancelled."; exit 1; }; eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true; eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true; else err "Homebrew required for tooling. Aborting."; exit 1; fi; fi
have git  || { err "git not found (expected in CLT)"; exit 1; }
have make || { err "make not found (expected in CLT)"; exit 1; }
have clang++ || { err "clang++ not found (expected in CLT)"; exit 1; }
log "All dependencies satisfied ✅"
