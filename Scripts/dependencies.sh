#!/bin/bash
# dependencies.sh — verify minimal toolchain; do not auto-install Homebrew
set -euo pipefail

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
warn(){ printf "%s [MacScope] [WARN] %s\n" "$(ts)" "$*" >&2; }
err(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; }

# Require Command Line Tools (clang++) and git
if ! command -v clang++ >/dev/null 2>&1; then
  err "Xcode Command Line Tools (clang++) not found. Open Terminal and run: xcode-select --install"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  err "git not found. Install Xcode Command Line Tools or git (e.g. via Homebrew)."
  exit 1
fi

# Optional developer conveniences
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found (optional). Skipping."
fi

log "All dependencies satisfied ✅"
