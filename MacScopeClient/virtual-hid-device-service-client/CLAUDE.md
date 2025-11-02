# Virtual HID Device Socket Relay Daemon - Complete Guide

## Overview

This is a Unix socket relay daemon that accepts JSON commands and translates them into Karabiner VirtualHID driver actions. It acts as a bridge between Swift applications and the low-level HID driver, allowing keyboard and mouse input simulation without requiring elevated privileges for each command.

## Architecture

```
Swift App (user)
     │
     ▼
  Unix Socket
 /tmp/macs_vhid_<uid>.sock
     │
     ▼
Socket Relay Daemon (this program - main.cpp)
     │
     ▼
Karabiner VirtualHID Driver
     │
     ▼
macOS DriverKit HID System
```

### Key Design Principles

1. **One-time sudo**: The daemon starts with sudo once, then Swift connects freely over the socket
2. **Sequential processing**: Commands are processed one at a time (mutex-protected)
3. **Non-blocking startup**: Socket server starts immediately, returns errors if driver not ready
4. **Structured responses**: Every command gets a JSON response with id, status, and timestamp

---

## Building & Running

### Prerequisites
- macOS 13.0 or later
- Xcode with command line tools
- Karabiner Virtual HID Driver installed

### Build
```bash
cd /path/to/virtual-hid-device-service-client
make
```

Output: `build/Release/virtual-hid-device-service-client`

### Run
```bash
# Start the daemon (requires sudo for driver access)
sudo ./build/Release/virtual-hid-device-service-client
```

The daemon will:
1. Connect to Karabiner VirtualHID driver
2. Create socket at `/tmp/macs_vhid_<uid>.sock`
3. Set permissions to `0660` owned by the original user
4. Start accepting connections

Press `Ctrl+C` to gracefully shut down.

---

## Socket Protocol

### Connection

**Socket path**: `/tmp/macs_vhid_<uid>.sock` where `<uid>` is your user ID

**From Swift**:
```swift
import Network

let socketPath = "/tmp/macs_vhid_\(getuid()).sock"
let endpoint = NWEndpoint.unix(path: socketPath)
let connection = NWConnection(to: endpoint, using: .tcp)
connection.start(queue: .main)
```

**From shell** (for testing):
```bash
echo '{"id":1,"type":"ping"}' | nc -U /tmp/macs_vhid_$(id -u).sock
```

### Request Format

All requests are JSON objects with these fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | No | Request ID (echoed back in response) |
| `type` | string | Yes | Command type: "ping", "click", "move", or "key" |
| ...additional fields depend on type... |

### Response Format

All responses are JSON objects:

```json
{
  "id": 42,
  "status": "ok",
  "timestamp": 1739992901
}
```

**On error**:
```json
{
  "id": 42,
  "status": "error",
  "message": "pointing device not ready",
  "timestamp": 1739992901
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Echoed from request (0 if not provided) |
| `status` | string | "ok" or "error" |
| `timestamp` | integer | Unix timestamp |
| `message` | string | Error description (only on error) |

---

## Commands

### 1. ping

**Purpose**: Check if daemon is responsive

**Request**:
```json
{
  "id": 1,
  "type": "ping"
}
```

**Response**:
```json
{
  "id": 1,
  "status": "ok",
  "timestamp": 1739992901
}
```

**Always succeeds** - useful for health checks.

---

### 2. click

**Purpose**: Perform a mouse click

**Request fields**:
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | string | - | Must be "click" |
| `button` | integer | 1 | Button number: 1=left, 2=right, 3=middle |
| `press` | integer | 100 | Duration to hold button down (milliseconds) |

**Examples**:

Left click (default):
```json
{
  "id": 2,
  "type": "click"
}
```

Right click with 200ms hold:
```json
{
  "id": 3,
  "type": "click",
  "button": 2,
  "press": 200
}
```

**Errors**:
- `"pointing device not ready"` - Driver not initialized yet
- `"button must be 1, 2, or 3"` - Invalid button number

---

### 3. move

**Purpose**: Move the mouse cursor relatively

**Request fields**:
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | string | - | Must be "move" |
| `x` | integer | 0 | Horizontal movement (+ = right, - = left) |
| `y` | integer | 0 | Vertical movement (+ = down, - = up) |

**Examples**:

Move right 100 pixels, down 50 pixels:
```json
{
  "id": 4,
  "type": "move",
  "x": 100,
  "y": 50
}
```

Move left 50 pixels:
```json
{
  "id": 5,
  "type": "move",
  "x": -50,
  "y": 0
}
```

**Note**: Movement is relative to current position, not absolute coordinates.

**Errors**:
- `"pointing device not ready"` - Driver not initialized yet

---

### 4. key

**Purpose**: Press keyboard keys

**Request fields**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be "key" |
| `key` | string | No* | Key name (e.g., "w", "space", "return") |
| `usage` | integer | No* | HID usage code (e.g., 26 for 'w') |
| `action` | string | No | Action: "press", "down", "up", "hold" (default: "press") |
| `press` | integer | No | For "hold" action: duration in ms (default: 1000) |

\* Must provide either `key` or `usage`

**Actions**:
- **`press`** (default): Press down + wait 50ms + release
- **`down`**: Press and hold (doesn't release)
- **`up`**: Release all keys
- **`hold`**: Press + wait for `press` duration + release

**Supported key names**:

| Category | Keys |
|----------|------|
| Letters | a-z |
| Numbers | 0-9 |
| Special | space, return, enter, escape, esc, tab, backspace |
| Arrows | up, down, left, right |

**Examples**:

Press 'w' once:
```json
{
  "id": 6,
  "type": "key",
  "key": "w",
  "action": "press"
}
```

Hold spacebar for 2 seconds:
```json
{
  "id": 7,
  "type": "key",
  "key": "space",
  "action": "hold",
  "press": 2000
}
```

Press using HID usage code:
```json
{
  "id": 8,
  "type": "key",
  "usage": 26,
  "action": "press"
}
```

Press and hold 'w' (doesn't release):
```json
{
  "id": 9,
  "type": "key",
  "key": "w",
  "action": "down"
}
```

Release all keys:
```json
{
  "id": 10,
  "type": "key",
  "key": "w",
  "action": "up"
}
```

**Errors**:
- `"keyboard device not ready"` - Driver not initialized yet
- `"unknown key name: xyz"` - Key name not in supported list
- `"missing 'key' or 'usage' field"` - Neither key nor usage provided
- `"unknown action: xyz"` - Invalid action type

---

## Swift Integration Example

```swift
import Network
import Foundation

class VHIDClient {
    private var connection: NWConnection?
    private var requestId = 0

    func connect() {
        let socketPath = "/tmp/macs_vhid_\(getuid()).sock"
        let endpoint = NWEndpoint.unix(path: socketPath)
        connection = NWConnection(to: endpoint, using: .tcp)
        connection?.start(queue: .main)
    }

    func sendCommand(_ command: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let connection = connection else {
            completion(.failure(NSError(domain: "VHIDClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"])))
            return
        }

        requestId += 1
        var cmd = command
        cmd["id"] = requestId

        guard let jsonData = try? JSONSerialization.data(withJSONObject: cmd),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        connection.send(content: jsonData, completion: .contentProcessed { error in
            if let error = error {
                completion(.failure(error))
                return
            }

            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }

                completion(.success(json))
            }
        })
    }

    // Convenience methods
    func ping(completion: @escaping (Bool) -> Void) {
        sendCommand(["type": "ping"]) { result in
            if case .success(let json) = result, json["status"] as? String == "ok" {
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    func click(button: Int = 1, press: Int = 100, completion: @escaping (Bool) -> Void) {
        sendCommand(["type": "click", "button": button, "press": press]) { result in
            completion(self.isSuccess(result))
        }
    }

    func move(x: Int, y: Int, completion: @escaping (Bool) -> Void) {
        sendCommand(["type": "move", "x": x, "y": y]) { result in
            completion(self.isSuccess(result))
        }
    }

    func pressKey(_ key: String, completion: @escaping (Bool) -> Void) {
        sendCommand(["type": "key", "key": key, "action": "press"]) { result in
            completion(self.isSuccess(result))
        }
    }

    func holdKey(_ key: String, duration: Int, completion: @escaping (Bool) -> Void) {
        sendCommand(["type": "key", "key": key, "action": "hold", "press": duration]) { result in
            completion(self.isSuccess(result))
        }
    }

    private func isSuccess(_ result: Result<[String: Any], Error>) -> Bool {
        if case .success(let json) = result, json["status"] as? String == "ok" {
            return true
        }
        return false
    }
}

// Usage:
let client = VHIDClient()
client.connect()

client.ping { success in
    print("Ping: \(success)")
}

client.click { success in
    print("Click: \(success)")
}

client.pressKey("w") { success in
    print("Press W: \(success)")
}
```

---

## Testing Commands

### Shell Test Examples

```bash
# Ping
echo '{"id":1,"type":"ping"}' | nc -U /tmp/macs_vhid_$(id -u).sock

# Left click
echo '{"id":2,"type":"click"}' | nc -U /tmp/macs_vhid_$(id -u).sock

# Right click
echo '{"id":3,"type":"click","button":2}' | nc -U /tmp/macs_vhid_$(id -u).sock

# Move mouse
echo '{"id":4,"type":"move","x":100,"y":50}' | nc -U /tmp/macs_vhid_$(id -u).sock

# Press 'w' key
echo '{"id":5,"type":"key","key":"w","action":"press"}' | nc -U /tmp/macs_vhid_$(id -u).sock

# Hold space for 2 seconds
echo '{"id":6,"type":"key","key":"space","action":"hold","press":2000}' | nc -U /tmp/macs_vhid_$(id -u).sock
```

### Expected Response Format

```json
{"id":1,"status":"ok","timestamp":1739992901}
```

---

## Error Handling

### Common Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `"driver not ready"` | VHD driver not connected | Wait a few seconds, retry |
| `"keyboard device not ready"` | Keyboard not initialized | Wait for driver connection |
| `"pointing device not ready"` | Mouse not initialized | Wait for driver connection |
| `"parse error: ..."` | Invalid JSON | Check JSON syntax |
| `"unknown command type: xyz"` | Invalid type field | Use: ping, click, move, or key |
| `"unknown key name: xyz"` | Key not supported | Check supported keys list |

### Driver States

The daemon tracks three readiness flags:

1. **driver_ready**: Driver connected
2. **keyboard_ready**: Keyboard device initialized
3. **pointing_ready**: Mouse device initialized

Commands will return errors until their respective device is ready.

---

## Troubleshooting

### Socket not found

**Error**: `No such file or directory` when connecting

**Solutions**:
1. Check if daemon is running: `ps aux | grep virtual-hid-device-service-client`
2. Verify socket path: `ls -l /tmp/macs_vhid_$(id -u).sock`
3. Restart the daemon

### Permission denied

**Error**: Cannot connect to socket

**Solutions**:
1. Check socket permissions: `ls -l /tmp/macs_vhid_$(id -u).sock`
2. Should be `0660` owned by your user
3. If wrong, restart daemon with correct sudo user

### Commands not working

**Error**: Getting "device not ready" errors

**Check daemon logs**:
```bash
# Look for these messages in daemon output:
VHD connected
VHD keyboard_ready: 1
VHD pointing_ready: 1
```

If not connected, ensure Karabiner VirtualHID driver is installed and running.

### Daemon crashes

**Check**:
1. Driver installed: Check for Karabiner DriverKit extension
2. Permissions: Run with `sudo`
3. Logs: Check stderr output for error messages

---

## Code Structure

```
main.cpp
├── Includes (lines 1-25)
│   ├── Standard C++ headers
│   ├── POSIX socket headers
│   ├── Karabiner VHD headers
│   └── nlohmann/json
├── Global State (lines 30-40)
│   ├── Exit flags and ready states
│   ├── Socket file descriptor
│   └── VHD client instance
├── Key Mapping (lines 43-95)
│   └── String names → HID usage codes
├── Signal Handler (lines 98-111)
│   └── Graceful shutdown on SIGINT/SIGTERM
├── VHD Setup (lines 114-183)
│   └── Connect and track driver state
├── Command Handlers (lines 186-418)
│   ├── handle_ping()
│   ├── handle_click()
│   ├── handle_move()
│   ├── handle_key()
│   └── handle_command() (dispatcher)
└── main() (lines 422-555)
    ├── Setup signal handlers
    ├── Initialize VHD client
    ├── Create and configure socket
    ├── Accept loop (sequential processing)
    └── Cleanup on exit
```

---

## Security Considerations

1. **Socket Permissions**: `0660` limits access to owner and group
2. **User Ownership**: Socket owned by original user (via SUDO_UID)
3. **No Authentication**: Assumes trusted local environment
4. **Sequential Processing**: Prevents race conditions via mutex
5. **Input Validation**: All command parameters validated before execution

---

## Future Enhancements

Potential improvements:

1. **Reconnection**: Auto-reconnect if driver disconnects
2. **Logging**: Optional log file output
3. **Authentication**: Token-based auth for multi-user systems
4. **Async Processing**: Worker thread pool for concurrent commands
5. **More Keys**: Support modifier keys (shift, ctrl, cmd, alt)
6. **Macros**: Support command sequences/scripts
7. **Status Endpoint**: Query driver/device states

---

## Reference

### HID Usage Codes

Common HID usage codes (can be used with `"usage"` field):

| Code | Key |
|------|-----|
| 4-29 | Letters a-z |
| 30-39 | Numbers 1-9, 0 |
| 40 | Return/Enter |
| 41 | Escape |
| 42 | Backspace |
| 43 | Tab |
| 44 | Spacebar |
| 79-82 | Arrow keys (right, left, down, up) |

Full list: [USB HID Usage Tables](https://usb.org/sites/default/files/hut1_5.pdf) - Section 10 (Keyboard/Keypad Page)

---

##Summary

This daemon provides a simple, secure bridge between Swift applications and the Karabiner VirtualHID driver. It:

- Runs with sudo once at startup
- Accepts JSON commands over a Unix socket
- Translates commands to HID driver actions
- Returns structured JSON responses
- Handles driver state transitions gracefully
- Supports keyboard and mouse input simulation

Perfect for building automation tools, accessibility features, or remote control applications on macOS.
