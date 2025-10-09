#!/bin/bash
# repair_perms.sh — optional: fix permissions on pqrs tmp dirs (root only)
set -euo pipefail

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
die(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run with administrator privileges."

ROOT="/Library/Application Support/org.pqrs/tmp"
mkdir -p "$ROOT/rootonly" "$ROOT/vhidd_server" 2>/dev/null || true
chmod 755 "$ROOT" "$ROOT/rootonly" "$ROOT/vhidd_server" 2>/dev/null || true
chown -R root:wheel "$ROOT" 2>/dev/null || true

log "Permissions repaired on $ROOT ✅"
