#!/bin/bash
# test_installation.sh - Verify MacScope VirtualHID installation

echo "=== MacScope VirtualHID Installation Test ==="
echo ""

PASS=0
FAIL=0
WARN=0

# Test 1: Check if Karabiner is installed
echo "[TEST 1] Checking Karabiner VirtualHID driver..."
if systemextensionsctl list 2>/dev/null | grep -q "Karabiner-DriverKit-VirtualHIDDevice"; then
    if systemextensionsctl list 2>/dev/null | grep -q "Karabiner-DriverKit-VirtualHIDDevice.*activated.*enabled"; then
        echo "✅ PASS: Karabiner driver is activated and enabled"
        ((PASS++))
    else
        echo "⚠️  WARN: Karabiner driver found but not activated/enabled"
        echo "   Action: Check System Settings > Privacy & Security"
        ((WARN++))
    fi
else
    echo "❌ FAIL: Karabiner driver not installed"
    echo "   Action: Install from https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases"
    ((FAIL++))
fi

# Test 2: Check if daemon process is running
echo "[TEST 2] Checking Karabiner daemon process..."
if pgrep -x "Karabiner-VirtualHIDDevice-Daemon" >/dev/null 2>&1; then
    PID=$(pgrep -x "Karabiner-VirtualHIDDevice-Daemon")
    echo "✅ PASS: Karabiner daemon running (PID: $PID)"
    ((PASS++))
else
    echo "❌ FAIL: Karabiner daemon not running"
    echo "   Action: Restart macOS or reinstall Karabiner"
    ((FAIL++))
fi

# Test 3: Check if binary exists
echo "[TEST 3] Checking macscope-vhid binary..."
if [[ -f /usr/local/bin/macscope-vhid ]]; then
    if [[ -x /usr/local/bin/macscope-vhid ]]; then
        PERMS=$(ls -l /usr/local/bin/macscope-vhid | awk '{print $1, $3, $4}')
        echo "✅ PASS: Binary exists with permissions: $PERMS"
        ((PASS++))
    else
        echo "⚠️  WARN: Binary exists but not executable"
        echo "   Action: sudo chmod 755 /usr/local/bin/macscope-vhid"
        ((WARN++))
    fi
else
    echo "❌ FAIL: Binary not found at /usr/local/bin/macscope-vhid"
    echo "   Action: Run installer"
    ((FAIL++))
fi

# Test 4: Check if plist exists
echo "[TEST 4] Checking LaunchDaemon plist..."
if [[ -f /Library/LaunchDaemons/com.macscope.vhid.relay.plist ]]; then
    PERMS=$(ls -l /Library/LaunchDaemons/com.macscope.vhid.relay.plist | awk '{print $1, $3, $4}')
    echo "✅ PASS: Plist exists with permissions: $PERMS"
    ((PASS++))
else
    echo "❌ FAIL: Plist not found at /Library/LaunchDaemons/com.macscope.vhid.relay.plist"
    echo "   Action: Run installer"
    ((FAIL++))
fi

# Test 5: Check if daemon is registered
echo "[TEST 5] Checking LaunchDaemon registration..."
if sudo launchctl print system/com.macscope.vhid.relay >/dev/null 2>&1; then
    STATE=$(sudo launchctl print system/com.macscope.vhid.relay 2>/dev/null | grep "state" | awk '{print $3}')
    if [[ "$STATE" == "running" ]]; then
        echo "✅ PASS: Daemon is registered and running"
        ((PASS++))
    else
        echo "⚠️  WARN: Daemon registered but state is: $STATE"
        echo "   Action: Check /var/log/macscope-vhid.log"
        ((WARN++))
    fi
else
    echo "❌ FAIL: Daemon not registered with launchctl"
    echo "   Action: sudo launchctl bootstrap system /Library/LaunchDaemons/com.macscope.vhid.relay.plist"
    ((FAIL++))
fi

# Test 6: Check if socket exists
echo "[TEST 6] Checking Unix socket..."
SOCKET_FOUND=0
for sock in /tmp/macs_vhid_*.sock /var/run/macscope/vhid_*.sock; do
    if [[ -S "$sock" ]]; then
        echo "✅ PASS: Socket found at $sock"
        SOCKET_FOUND=1
        ((PASS++))
        break
    fi
done
if [[ $SOCKET_FOUND -eq 0 ]]; then
    echo "⚠️  WARN: No socket found (daemon may still be starting)"
    echo "   Action: Wait 30 seconds or check /var/log/macscope-vhid.log"
    ((WARN++))
fi

# Test 7: Check logs
echo "[TEST 7] Checking daemon logs..."
if [[ -f /var/log/macscope-vhid.log ]]; then
    if tail -20 /var/log/macscope-vhid.log | grep -q "VirtualHID relay listening"; then
        echo "✅ PASS: Daemon log shows successful startup"
        ((PASS++))
    elif tail -20 /var/log/macscope-vhid.log | grep -q "Waiting for Karabiner"; then
        echo "⚠️  WARN: Daemon is waiting for Karabiner (normal on first boot)"
        ((WARN++))
    elif tail -20 /var/log/macscope-vhid.log | grep -q "ERROR"; then
        echo "❌ FAIL: Daemon log shows errors"
        echo "   Last error:"
        tail -5 /var/log/macscope-vhid.log | grep ERROR
        ((FAIL++))
    else
        echo "⚠️  WARN: Daemon log exists but unclear status"
        ((WARN++))
    fi
else
    echo "⚠️  WARN: Daemon log not found at /var/log/macscope-vhid.log"
    ((WARN++))
fi

# Test 8: Check version file
echo "[TEST 8] Checking version tracking..."
if [[ -f /usr/local/lib/macscope/VERSION ]]; then
    VERSION=$(cat /usr/local/lib/macscope/VERSION)
    echo "✅ PASS: Version file found: $VERSION"
    ((PASS++))
else
    echo "⚠️  WARN: Version file not found (not critical)"
    ((WARN++))
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "✅ Passed: $PASS"
echo "⚠️  Warnings: $WARN"
echo "❌ Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 && $WARN -eq 0 ]]; then
    echo "🎉 All tests passed! Installation is working correctly."
    exit 0
elif [[ $FAIL -eq 0 ]]; then
    echo "⚠️  Installation mostly working but has warnings. Check actions above."
    exit 0
else
    echo "❌ Installation has failures. Follow action items above to fix."
    exit 1
fi
