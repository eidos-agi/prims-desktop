#!/bin/bash
# Autonomous prove. Agents run this — not AppleScript, not screenshots.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(realpath "$ROOT")"
cd "$ROOT"
export PATH="$HOME/.local/bin:$HOME/.asmp/bin:$PATH"

if ! command -v prims-desktop >/dev/null 2>&1; then
  echo "prims-desktop not on PATH — install with ./scripts/install-cli.sh" >&2
  exit 1
fi

python3 "$ROOT/scripts/litmus.py"
prims-desktop asmp
prims-desktop doctor
prims-desktop connectors
prims-desktop status imessage-chatdb-receive || true

ASMP_BIN="$(command -v asmp || true)"
if [[ -z "$ASMP_BIN" ]]; then
  echo "asmp not on PATH" >&2
  exit 1
fi
"$ASMP_BIN" get prims-desktop
"$ASMP_BIN" caps | grep -F 'connector.imessage-chatdb-receive'

# Every live connector cap is advertised.
while read -r name; do
  [[ -z "$name" ]] && continue
  "$ASMP_BIN" caps | grep -F "connector.${name}"
done < <(prims-desktop --json connectors | python3 -c 'import json,sys; [print(r["name"]) for r in json.load(sys.stdin)["connectors"]]')

if command -v eamd >/dev/null 2>&1; then
  eamd asmp | grep -E 'prims-desktop|imessage-chatdb|opff-dally|docket-webmcp|prim-viewer'
fi

if [[ -d ../prim-sim ]]; then
  swift test --filter HostTests.testCLIConnectorsListsMergedOverlay \
    --filter HostTests.testCLIConfigSetPreservesOpff \
    --filter HostTests.testCLIReceiveUnknownConnectorFails \
    --filter HostTests.testCLIReceiveRejectsNonIMessageConnector \
    --filter HostTests.testRegistryListsConnectors \
    --filter HostTests.testNoMintedToolTypes \
    --filter HostTests.testPreferredConnectorIsIMessage \
    --filter HostTests.testStarCiteDoesNotMintPackTypes \
    --filter HostTests.testASMPLiveCapsFollowHostCatalog \
    --filter HostTests.testASMPConnectorManifestIsAServiceNotAPackType
else
  echo "skip swift test (../prim-sim missing)"
fi

echo "PROVE OK"
