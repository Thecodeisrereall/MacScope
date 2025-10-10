// Minimal macscope-vhid CLI
// This program connects to the macs_vhidrelay UNIX socket for the current user,
// sends a "ping" message, and prints the response.
// Usage: simply run the executable; no arguments are required.

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <string>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <iostream>

int main() {
    using std::string;
    using std::cerr;
    using std::cout;
    using std::endl;

    uid_t uid = getuid();
    string socket_path = "/var/run/macs_vhidrelay." + std::to_string(uid) + ".sock";

    int sock_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock_fd < 0) {
        perror("socket");
        return 1;
    }

    struct sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    if (sizeof(addr.sun_path) <= socket_path.size()) {
        cerr << "Socket path too long: " << socket_path << endl;
        close(sock_fd);
        return 1;
    }
    std::strncpy(addr.sun_path, socket_path.c_str(), sizeof(addr.sun_path) - 1);
    addr.sun_path[sizeof(addr.sun_path) - 1] = '\0';

    if (connect(sock_fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) != 0) {
        cerr << "Failed to connect to socket '" << socket_path << "': " << strerror(errno) << endl;
        close(sock_fd);
        return 1;
    }

    const char* msg = "ping\n";
    ssize_t bytes_written = write(sock_fd, msg, 5);
    if (bytes_written != 5) {
        perror("write");
        close(sock_fd);
        return 1;
    }

    char buffer[256];
    ssize_t bytes_read = read(sock_fd, buffer, sizeof(buffer) - 1);
    if (bytes_read < 0) {
        perror("read");
        close(sock_fd);
        return 1;
    } else if (bytes_read == 0) {
        cerr << "No data received from socket." << endl;
        close(sock_fd);
        return 1;
    }

    buffer[bytes_read] = '\0';
    cout << buffer << endl;

    close(sock_fd);
    return 0;
}
