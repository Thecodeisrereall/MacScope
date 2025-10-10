// Minimal macscope-vhid CLI
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <string>
#include <cstdio>
#include <cstring>
int main(){uid_t uid=getuid();std::string p="/var/run/macs_vhidrelay."+std::to_string(uid)+".sock";int s=socket(AF_UNIX,SOCK_STREAM,0);sockaddr_un a{};a.sun_family=AF_UNIX;snprintf(a.sun_path,sizeof(a.sun_path),"%s",p.c_str());if(connect(s,(sockaddr*)&a,sizeof(a))!=0){perror("connect");return 1;}write(s,"ping\n",5);char b[256];int n=read(s,b,255);if(n>0){b[n]=0;puts(b);}close(s);}
