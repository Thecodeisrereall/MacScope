// Minimal macscope-vhid-relay
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <string>
#include <cstdio>
#include <cstring>
volatile sig_atomic_t stopflag = 0;
void on_signal(int){ stopflag = 1; }
int main(int argc, char** argv){
    uid_t uid = getuid();
    std::string path = "/var/run/macs_vhidrelay." + std::to_string(uid) + ".sock";
    unlink(path.c_str());
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    sockaddr_un a{}; a.sun_family = AF_UNIX; snprintf(a.sun_path, sizeof(a.sun_path), "%s", path.c_str());
    bind(s,(sockaddr*)&a,sizeof(a)); chmod(path.c_str(),0600); listen(s,4);
    fprintf(stderr,"[vhid-relay:min] listening %s\n",path.c_str());
    while(!stopflag){int c=accept(s,nullptr,nullptr);if(c<0)continue;char buf[256];int n=read(c,buf,255);if(n>0){buf[n]=0;if(strstr(buf,"ping"))write(c,"{\"ok\":true,\"msg\":\"pong\"}\n",32);}close(c);}close(s);unlink(path.c_str());}
