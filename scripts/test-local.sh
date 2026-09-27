#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-daemon.sh"
"$ROOT/tests/test-protocol.sh"
echo "Local tests passed."
