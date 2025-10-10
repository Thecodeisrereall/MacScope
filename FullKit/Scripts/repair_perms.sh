#!/bin/bash
# repair_perms.sh — optional: fix permissions on pqrs tmp dirs and vHID-related files (root only)
set -euo pipefail

LOG_DIR="/var/log/macscope-vhid"
LOG_FILE="$LOG_DIR/repair_perms.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
exec >> "$LOG_FILE" 2>&1

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s [MacScope] %s\n" "$(ts)" "$*"; }
die(){ printf "%s [MacScope] [ERROR] %s\n" "$(ts)" "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run with administrator privileges."

ROOT="/Library/Application Support/org.pqrs/tmp"
mkdir -p "$ROOT/rootonly" "$ROOT/vhidd_server" 2>/dev/null || true
chmod 755 "$ROOT" "$ROOT/rootonly" "$ROOT/vhidd_server" 2>/dev/null || true
chown -R root:wheel "$ROOT" 2>/dev/null || true
log "Permissions repaired on $ROOT ✅"

declare -a files=(
  "/usr/local/bin/vhidctl"
  "/usr/local/bin/vhidrelay"
  "/usr/local/bin/macscope-vhid"
  "/Library/LaunchDaemons/com.macscope.vhidrelay.plist"
)

fixed_count=0

for file in "${files[@]}"; do
  if [ -e "$file" ]; then
    # Save original perms and ownership
    orig_perm=$(stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null || echo "")
    orig_owner=$(stat -f "%Su:%Sg" "$file" 2>/dev/null || stat -c "%U:%G" "$file" 2>/dev/null || echo "")
    # Set ownership to root:wheel
    chown root:wheel "$file" 2>/dev/null || true
    # Set permissions to 755 for executables, 644 for plist
    if [[ "$file" == *.plist ]]; then
      chmod 644 "$file" 2>/dev/null || true
    else
      chmod 755 "$file" 2>/dev/null || true
    fi
    # Check if changed
    new_perm=$(stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null || echo "")
    new_owner=$(stat -f "%Su:%Sg" "$file" 2>/dev/null || stat -c "%U:%G" "$file" 2>/dev/null || echo "")
    if [[ "$orig_perm" != "$new_perm" || "$orig_owner" != "$new_owner" ]]; then
      log "Permissions repaired on $file ✅"
      ((fixed_count++))
    fi
  else
    log "File not found: $file"
  fi
done

log "Total repaired items: $fixed_count"
