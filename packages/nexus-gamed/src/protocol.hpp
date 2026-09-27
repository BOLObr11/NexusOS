#pragma once
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace nexus {
enum class CommandType { Status, Start, Stop, Ping, Invalid };
struct Command { CommandType type{CommandType::Invalid}; std::uint32_t pid{0}; std::string name; };

inline std::vector<std::string> split_ws(const std::string& input) {
    std::vector<std::string> out;
    std::string cur;
    for (char c : input) {
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            if (!cur.empty()) { out.push_back(cur); cur.clear(); }
        } else cur.push_back(c);
    }
    if (!cur.empty()) out.push_back(cur);
    return out;
}

inline std::optional<std::uint32_t> parse_pid(const std::string& s) {
    if (s.empty() || s.size() > 10) return std::nullopt;
    std::uint64_t v = 0;
    for (char c : s) {
        if (c < '0' || c > '9') return std::nullopt;
        v = v * 10 + static_cast<unsigned>(c - '0');
        if (v > 0xFFFFFFFFu) return std::nullopt;
    }
    if (v == 0) return std::nullopt;
    return static_cast<std::uint32_t>(v);
}

inline Command parse_command(const std::string& line) {
    if (line.size() > 512) return {};
    const auto p = split_ws(line);
    if (p.empty()) return {};
    if (p[0] == "PING" && p.size() == 1) return {CommandType::Ping, 0, {}};
    if (p[0] == "STATUS" && p.size() == 1) return {CommandType::Status, 0, {}};
    if (p[0] == "STOP" && p.size() == 1) return {CommandType::Stop, 0, {}};
    if (p[0] == "START" && (p.size() == 2 || p.size() == 3)) {
        auto pid = parse_pid(p[1]);
        if (!pid) return {};
        std::string name = p.size() == 3 ? p[2] : "game";
        if (name.size() > 96) return {};
        for (char c : name) {
            const bool safe = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                              (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.';
            if (!safe) return {};
        }
        return {CommandType::Start, *pid, std::move(name)};
    }
    return {};
}
} // namespace nexus
