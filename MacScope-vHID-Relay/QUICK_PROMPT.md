# Quick Prompt - MacScope Build Fix

Use this compact prompt for quick Claude iterations:

---

**Fix MacScope VirtualHID installer build section:**

Stage 4 fails because `make` expects Karabiner's `scripts/update_version.py` which doesn't exist in our MacScopeClient repo.

**Requirements:**
- Compile MacScopeClient/virtual-hid-device-service-client/src/main.cpp standalone
- Use clang++ directly (no make/xcodegen)
- Include headers from: Karabiner-DriverKit-VirtualHIDDevice/include
- Output: /usr/local/bin/macscope-vhid (755 root:wheel)
- Auto-clone headers if missing (sparse checkout to /tmp)
- Log all steps with timestamps

**Source locations:**
```
/Users/meklows/Documents/GitHub/MacScope/MacScopeClient/virtual-hid-device-service-client/
/Users/meklows/Documents/GitHub/MacScope/Karabiner-DriverKit-VirtualHIDDevice/include/
```

**Compiler flags (from project.yml):**
```
-std=gnu++2a -Wall -Werror -O2 -mmacosx-version-min=13.0
-framework Foundation -framework IOKit
```

Return revised Stage 4 bash code only.

---

## Even Shorter Version

Fix MacScope installer Stage 4:
- Replace `make` with direct `clang++` compilation
- Source: `MacScopeClient/virtual-hid-device-service-client/src/main.cpp`
- Headers: `Karabiner-DriverKit-VirtualHIDDevice/include/` (clone if missing)
- Output: `/usr/local/bin/macscope-vhid`
- No dependencies on Karabiner build scripts

Return Stage 4 code.
