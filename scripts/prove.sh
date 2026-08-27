#!/bin/bash
# Autonomous prove. Agents run this — not AppleScript, not screenshots.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v prims-desktop >/dev/null 2>&1; then
  prims-desktop doctor
  prims-desktop connectors
  prims-desktop status imessage-chatdb-receive || true
else
  echo "prims-desktop not on PATH — install with ./scripts/install-cli.sh" >&2
  exit 1
fi

if [[ -d ../prim-sim ]]; then
  swift test --filter HostTests
else
  echo "skip swift test (../prim-sim missing)"
fi

echo "PROVE OK"
