#!/bin/bash
# Unattended: overlay unit tests + mini self-test. No UI, no Daniel.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "== RegistryLocalOverlayTests (prim-sim) =="
cd "$ROOT/../prim-sim"
swift test --filter RegistryLocalOverlayTests
echo "== mini opff-dally-receive --self-test =="
ssh -o BatchMode=yes -o ConnectTimeout=15 mac-mini-01 'export PATH=$HOME/.local/bin:/opt/homebrew/bin:$PATH; opff-dally-receive --self-test'
echo "== ALL PASS =="
