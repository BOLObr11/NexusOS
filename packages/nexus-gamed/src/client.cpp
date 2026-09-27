#include <cstring>
#include <iostream>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

namespace {
constexpr const char* kSocket = "/run/nexus/nexus-gamed.sock";

std::string usage() {
    return "Usage:\n"
           "  nexusctl status\n"
           "  nexusctl start <pid> [name]\n"
           "  nexusctl stop\n"
           "  nexusctl ping\n";
}
}

int main(int argc, char** argv) {
    if (argc < 2) { std::cerr << usage(); return 2; }
    std::string request;
    const std::string cmd = argv[1];
    if (cmd == "status" && argc == 2) request = "STATUS\n";
    else if (cmd == "stop" && argc == 2) request = "STOP\n";
    else if (cmd == "ping" && argc == 2) request = "PING\n";
    else if (cmd == "start" && (argc == 3 || argc == 4)) {
        request = "START " + std::string(argv[2]);
        if (argc == 4) request += " " + std::string(argv[3]);
        request += "\n";
    } else { std::cerr << usage(); return 2; }

    const int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) { std::cerr << "socket failed\n"; return 1; }
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, kSocket, sizeof(addr.sun_path) - 1);
    if (connect(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        std::cerr << "Cannot connect to nexus-gamed at " << kSocket << "\n";
        close(fd); return 1;
    }
    if (write(fd, request.data(), request.size()) < 0) { close(fd); return 1; }
    char buf[1024]{};
    const ssize_t n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n <= 0) return 1;
    std::cout.write(buf, n);
    return 0;
}
