# Payload Directory

This directory contains the binary and configuration files for installation.

## Required Files

- `macscope-vhid` - The compiled relay binary (excluded from git, copy your binary here)
- `com.macscope.vhid.relay.plist` - LaunchDaemon configuration

## Before Installation

1. Build your relay binary from source
2. Copy the compiled `macscope-vhid` binary to this directory:
   ```bash
   cp /path/to/your/build/macscope-vhid ./payload/
   ```
3. Verify the binary is executable:
   ```bash
   file ./payload/macscope-vhid
   chmod +x ./payload/macscope-vhid
   ```

## Binary Requirements

The binary must:
- Be a Mach-O 64-bit executable
- Be compiled for arm64 or universal (arm64 + x86_64)
- Have execute permissions
- Be properly signed (for distribution)
