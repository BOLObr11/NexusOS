#include "protocol.hpp"

#include <array>
#include <cerrno>
#include <csignal>
#include <cstring>
#include <filesystem>
#include <grp.h>
#include <iostream>
#include <optional>
#include <string>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>

namespace fs = std::filesystem;
namespace {
constexpr const char* kSocket = "/run/nexus/nexus-gamed.sock";
volatile std::sig_atomic_t g_stop = 0;
struct Session { std::uint32_t pid; std::string name; };
std::optional<Session> g_session;
void on_signal(int) { g_stop = 1; }
bool pid_exists(std::uint32_t pid) { return fs::exists("/proc/" + std::to_string(pid)); }

int run_program(const std::vector<std::string>& args) {
    if (args.empty()) return -1;
    pid_t child = fork();
    if (child < 0) return -1;
    if (child == 0) {
        std::vector<char*> argv;
        argv.reserve(args.size() + 1);
        for (const auto& s : args) argv.push_back(const_cast<char*>(s.c_str()));
        argv.push_back(nullptr);
        execvp(argv[0], argv.data());
        _exit(127);
    }
    int status = 0;
    if (waitpid(child, &status, 0) < 0) return -1;
    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

void set_power_profile(const char* profile) { (void)run_program({"powerprofilesctl", "set", profile}); }
void apply_game_priority(std::uint32_t pid) {
    (void)run_program({"renice", "-n", "-5", "-p", std::to_string(pid)});
    (void)run_program({"ionice", "-c", "2", "-n", "0", "-p", std::to_string(pid)});
}
void restore_process_priority(std::uint32_t pid) {
    if (!pid_exists(pid)) return;
    (void)run_program({"renice", "-n", "0", "-p", std::to_string(pid)});
    (void)run_program({"ionice", "-c", "2", "-n", "4", "-p", std::to_string(pid)});
}

std::string handle(const nexus::Command& cmd) {
    using nexus::CommandType;
    switch (cmd.type) {
        case CommandType::Ping: return "OK PONG\n";
        case CommandType::Status:
            if (!g_session) return "OK IDLE\n";
            return "OK ACTIVE " + std::to_string(g_session->pid) + " " + g_session->name + "\n";
        case CommandType::Start:
            if (!pid_exists(cmd.pid)) return "ERR PID_NOT_FOUND\n";
            if (g_session) restore_process_priority(g_session->pid);
            set_power_profile("performance");
            apply_game_priority(cmd.pid);
            g_session = Session{cmd.pid, cmd.name};
            return "OK STARTED " + std::to_string(cmd.pid) + " " + cmd.name + "\n";
        case CommandType::Stop:
            if (g_session) restore_process_priority(g_session->pid);
            g_session.reset();
            set_power_profile("balanced");
            return "OK STOPPED\n";
        default: return "ERR BAD_REQUEST\n";
    }
}

int make_socket() {
    unlink(kSocket);
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return -1;
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, kSocket, sizeof(addr.sun_path) - 1);
    if (bind(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) { close(fd); return -1; }
    if (const group* g = getgrnam("nexus-game")) {
        if (chown(kSocket, 0, g->gr_gid) != 0) {
            std::cerr << "nexus-gamed: warning: could not set socket group: " << std::strerror(errno) << "\n";
        }
    }
    if (chmod(kSocket, 0660) != 0) {
        std::cerr << "nexus-gamed: warning: could not set socket permissions: " << std::strerror(errno) << "\n";
    }
    if (listen(fd, 16) < 0) { close(fd); return -1; }
    return fd;
}
}

int main() {
    std::signal(SIGTERM, on_signal);
    std::signal(SIGINT, on_signal);
    const int server = make_socket();
    if (server < 0) {
        std::cerr << "nexus-gamed: socket setup failed: " << std::strerror(errno) << "\n";
        return 1;
    }
    while (!g_stop) {
        const int client = accept4(server, nullptr, nullptr, SOCK_CLOEXEC);
        if (client < 0) { if (errno == EINTR) continue; break; }
        std::array<char, 513> buf{};
        const ssize_t n = read(client, buf.data(), 512);
        std::string reply = "ERR EMPTY\n";
        if (n > 0) reply = handle(nexus::parse_command(std::string(buf.data(), static_cast<std::size_t>(n))));
        const ssize_t written = write(client, reply.data(), reply.size());
        if (written < 0) {
            std::cerr << "nexus-gamed: warning: socket write failed: " << std::strerror(errno) << "\n";
        }
        close(client);
    }
    if (g_session) restore_process_priority(g_session->pid);
    set_power_profile("balanced");
    close(server);
    unlink(kSocket);
    return 0;
}
