#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/test.cpp" <<'CPP'
#include "protocol.hpp"
#include <cassert>
int main() {
  using namespace nexus;
  assert(parse_command("PING\n").type == CommandType::Ping);
  assert(parse_command("STATUS\n").type == CommandType::Status);
  assert(parse_command("STOP\n").type == CommandType::Stop);
  auto a = parse_command("START 1234 valorant\n");
  assert(a.type == CommandType::Start && a.pid == 1234 && a.name == "valorant");
  assert(parse_command("START 0 nope\n").type == CommandType::Invalid);
  assert(parse_command("START x nope\n").type == CommandType::Invalid);
  assert(parse_command("START 12 bad/name\n").type == CommandType::Invalid);
  assert(parse_command(std::string(600, 'A')).type == CommandType::Invalid);
}
CPP
g++ -std=c++20 -Wall -Wextra -Wpedantic -Werror -I"$ROOT/packages/nexus-gamed/src" "$TMP/test.cpp" -o "$TMP/test"
"$TMP/test"
