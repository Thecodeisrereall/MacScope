#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
need_cmd clang++

TMP="${TMPDIR:-/tmp}/macscope_build_$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"
cd "$TMP"

cat > macscope-vhid.cpp <<"EOF"
// macscope-vhid.cpp — improved ping client
#include <iostream>
#include <vector>
#include <string>
#include <cstring>
#include <dirent.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <chrono>
#include <thread>
#include <sys/stat.h>

static const char* kDirs[] = {
  "/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server",
  "/Library/Application Support/org.pqrs/tmp/vhidd_server"
};

static bool is_root(){ return ::geteuid() == 0; }

static bool is_socket(const std::string& path) {
  struct stat st{};
  if (::stat(path.c_str(), &st) != 0) return false;
  return S_ISSOCK(st.st_mode);
}

static std::vector<std::string> list_socks(const char* dirPath){
  std::vector<std::string> v; DIR* d = ::opendir(dirPath); if(!d) return v; dirent* e;
  while((e = ::readdir(d))){
    std::string n(e->d_name);
    if(n=="."||n=="..") continue;
    std::string p = std::string(dirPath)+"/"+n;
    if (is_socket(p)) v.push_back(p);
  }
  ::closedir(d); return v;
}

static bool try_connect(const std::string& p){
  int fd = ::socket(AF_UNIX, SOCK_STREAM, 0); if(fd<0) return false;
  sockaddr_un a{}; a.sun_family = AF_UNIX; std::snprintf(a.sun_path, sizeof(a.sun_path), "%s", p.c_str());
  bool ok = (::connect(fd, (sockaddr*)&a, sizeof(a))==0); ::close(fd); return ok;
}

int main(int argc, char** argv){
  if(argc>=2 && std::string(argv[1])=="ping"){
    if(!is_root()){
      std::cerr<<"macscope-vhid: run as root (sudo).\n";
      return 2;
    }
    // retries ~6s total
    for(int i=0;i<30;i++){
      for (auto dir : kDirs){
        auto socks = list_socks(dir);
        for(auto& p:socks){
          if(try_connect(p)){
            std::cout<<"ping OK ("<<p<<")\n";
            return 0;
          }
        }
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }
    // verbose diagnostics
    std::cerr<<"ping FAILED: no connectable sockets in:\n";
    for (auto dir : kDirs){
      std::cerr<<"  "<<dir<<"\n";
      auto socks = list_socks(dir);
      if (socks.empty()) std::cerr<<"    (no sockets found)\n";
      for (auto& p : socks) std::cerr<<"    "<<p<<"\n";
    }
    return 1;
  }
  std::cerr<<"usage: macscope-vhid ping\n"; return 64;
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
