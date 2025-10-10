// Minimal macscope-vhid-relay
// 
// This program creates a Unix domain socket relay for macscope vhid communication.
// It listens on a socket file unique to the user ID (UID) and responds to "ping" messages with a JSON "pong".
// Usage: Run the program; it will create and listen on /var/run/macs_vhidrelay.<UID>.sock.
// The relay handles SIGINT and SIGTERM signals for graceful shutdown.
// Logs are written to stderr with timestamps.
//
// Note: Ensure the program has appropriate permissions to create and bind to the socket path.

#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <string>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <cerrno>

volatile sig_atomic_t stopflag = 0;

void on_signal(int) {
    stopflag = 1;
}

void log_msg(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    time_t now = time(nullptr);
    struct tm tm_now;
    localtime_r(&now, &tm_now);
    char timebuf[20];
    strftime(timebuf, sizeof(timebuf), "%Y-%m-%d %H:%M:%S", &tm_now);
    fprintf(stderr, "[%s] ", timebuf);
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    va_end(args);
}

int main(int argc, char** argv) {
    uid_t uid = getuid();
    std::string path = "/var/run/macs_vhidrelay." + std::to_string(uid) + ".sock";

    struct sigaction sa {};
    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGINT, &sa, nullptr) == -1) {
        perror("sigaction SIGINT");
        return 1;
    }
    if (sigaction(SIGTERM, &sa, nullptr) == -1) {
        perror("sigaction SIGTERM");
        return 1;
    }

    unlink(path.c_str());

    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s < 0) {
        perror("socket");
        return 1;
    }

    sockaddr_un a{};
    a.sun_family = AF_UNIX;
    if (snprintf(a.sun_path, sizeof(a.sun_path), "%s", path.c_str()) >= (int)sizeof(a.sun_path)) {
        log_msg("Socket path is too long");
        close(s);
        return 1;
    }

    if (bind(s, (sockaddr*)&a, sizeof(a)) < 0) {
        perror("bind");
        close(s);
        return 1;
    }

    if (chmod(path.c_str(), 0600) < 0) {
        perror("chmod");
        close(s);
        unlink(path.c_str());
        return 1;
    }

    if (listen(s, 4) < 0) {
        perror("listen");
        close(s);
        unlink(path.c_str());
        return 1;
    }

    log_msg("Listening on %s", path.c_str());

    while (!stopflag) {
        int c = accept(s, nullptr, nullptr);
        if (c < 0) {
            if (errno == EINTR) {
                // Interrupted by signal, check stopflag
                continue;
            }
            perror("accept");
            break;
        }

        char buf[256];
        ssize_t n = read(c, buf, sizeof(buf) - 1);
        if (n > 0) {
            buf[n] = 0;
            if (strstr(buf, "ping")) {
                const char* pong = "{\"ok\":true,\"msg\":\"pong\"}\n";
                ssize_t written = write(c, pong, strlen(pong));
                if (written < 0) {
                    perror("write");
                }
            }
        } else if (n < 0) {
            perror("read");
        }

        close(c);
    }

    log_msg("Shutting down, cleaning up socket");

    close(s);
    unlink(path.c_str());

    return 0;
}
