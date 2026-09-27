#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-daemon.sh"
install -Dm0755 "$ROOT/build/nexus-gamed/nexus-gamed" "$ROOT/os/files/usr/libexec/nexus/nexus-gamed"
install -Dm0755 "$ROOT/build/nexus-gamed/nexusctl" "$ROOT/os/files/usr/bin/nexusctl"
