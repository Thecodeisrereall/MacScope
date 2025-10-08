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
// macscope-vhid.cpp — minimal root-only ping client
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
static const char* kDir = "/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server";
static bool is_root(){ return ::geteuid() == 0; }
static std::vector<std::string> list_socks(){
  std::vector<std::string> v; DIR* d = ::opendir(kDir); if(!d) return v; dirent* e;
  while((e = ::readdir(d))){ std::string n(e->d_name); if(n=="."||n=="..") continue; if(n.size()>5 && n.substr(n.size()-5)==".sock") v.push_back(std::string(kDir)+"/"+n); }
  ::closedir(d); return v;
}
static bool try_connect(const std::string& p){
  int fd = ::socket(AF_UNIX, SOCK_STREAM, 0); if(fd<0) return false;
  sockaddr_un a{}; a.sun_family = AF_UNIX; std::snprintf(a.sun_path, sizeof(a.sun_path), "%s", p.c_str());
  bool ok = (::connect(fd, (sockaddr*)&a, sizeof(a))==0); ::close(fd); return ok;
}
int main(int argc, char** argv){
  if(argc>=2 && std::string(argv[1])=="ping"){
    if(!is_root()){ std::cerr<<"macscope-vhid: run as root (sudo).\\n"; return 2; }
    for(int i=0;i<10;i++){ auto s=list_socks(); for(auto& p:s){ if(try_connect(p)){ std::cout<<"ping OK ("<<p<<")\\n"; return 0; } }
      std::this_thread::sleep_for(std::chrono::milliseconds(150)); }
    std::cerr<<"ping FAILED: no connectable sockets.\\n"; return 1;
  }
  std::cerr<<"usage: macscope-vhid ping\\n"; return 64;
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
