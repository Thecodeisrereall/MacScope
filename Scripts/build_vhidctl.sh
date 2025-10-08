#!/bin/bash
# build_vhidctl.sh — now builds our minimal client as /usr/local/bin/macscope-vhid
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
need_cmd clang++
TMP="${TMPDIR:-/tmp}/macscope_build_$$"; trap 'rm -rf "$TMP"' EXIT; mkdir -p "$TMP"; cd "$TMP"
cat > macscope-vhid.cpp <<"EOF"
// macscope-vhid.cpp — minimal root-only ping client for Karabiner VirtualHID daemon
// Build: clang++ -std=c++17 -O2 macscope-vhid.cpp -o macscope-vhid
// Usage: sudo macscope-vhid ping
#include <iostream>
#include <vector>
#include <string>
#include <cstring>
#include <cerrno>
#include <dirent.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <unistd.h>
#include <chrono>
#include <thread>

static const char* kSocketDir = "/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server";

static bool is_root() {
  return ::geteuid() == 0;
}

static std::vector<std::string> list_sockets() {
  std::vector<std::string> out;
  DIR* dir = ::opendir(kSocketDir);
  if (!dir) return out;
  struct dirent* de;
  while ((de = ::readdir(dir)) != nullptr) {
    std::string name(de->d_name);
    if (name == "." || name == "..") continue;
    if (name.size() >= 5 && name.substr(name.size()-5) == ".sock") {
      out.push_back(std::string(kSocketDir) + "/" + name);
    }
  }
  ::closedir(dir);
  return out;
}

static bool try_connect(const std::string& path) {
  int fd = ::socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0) return false;
  struct sockaddr_un addr;
  std::memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  std::snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", path.c_str());
  bool ok = (::connect(fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) == 0);
  ::close(fd);
  return ok;
}

static int cmd_ping() {
  if (!is_root()) {
    std::cerr << "macscope-vhid: must be run as root (sudo) to access daemon socket.\n";
    return 2;
  }

  for (int attempt = 0; attempt < 10; ++attempt) {
    auto socks = list_sockets();
    for (const auto& s : socks) {
      if (try_connect(s)) {
        std::cout << "ping OK (" << s << ")\n";
        return 0;
      }
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(150));
  }

  std::cerr << "ping FAILED: could not connect to any *.sock in\n  " << kSocketDir << "\n";
  return 1;
}

int main(int argc, char** argv) {
  if (argc >= 2 && std::string(argv[1]) == "ping") {
    return cmd_ping();
  }
  std::cerr << "usage: macscope-vhid ping\n";
  return 64;
}

EOF
log "Compiling macscope-vhid…"
clang++ -std=c++17 -O2 macscope-vhid.cpp -o macscope-vhid
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then SUDO=sudo; else SUDO=; fi
$SUDO install -m 755 macscope-vhid /usr/local/bin/macscope-vhid
$SUDO chown root:wheel /usr/local/bin/macscope-vhid || true
$SUDO xattr -dr com.apple.quarantine /usr/local/bin/macscope-vhid 2>/dev/null || true
log "Installed /usr/local/bin/macscope-vhid ✅"
log "Try: sudo macscope-vhid ping"
