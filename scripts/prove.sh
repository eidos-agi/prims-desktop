#!/bin/bash
# Autonomous prove. Agents run this — not AppleScript, not screenshots.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(realpath "$ROOT")"
cd "$ROOT"
export PATH="$HOME/.local/bin:$HOME/.asmp/bin:$PATH"

# Process-entry + XPC source lock. FDA prove is in-app Messages, not piped doctor.
python3 - <<'PY'
from pathlib import Path
root = Path(".").resolve()
app = (root / "Sources/PrimMac/App.swift").read_text()
main = (root / "Sources/PrimMac/PrimDesktopMain.swift").read_text()
if any(line == "@main" or line.startswith("@main ") for line in app.splitlines()):
    raise SystemExit("PrimApp is still the process entry")
if "DesktopCLI" in app:
    raise SystemExit("App.swift peeks DesktopCLI — that is an init() gate")
if "@main" not in main or "PrimsDesktopXPCClient.run" not in main or "flushAndExit" not in main:
    raise SystemExit("PrimDesktopMain must @main, XPC-client CLI verbs, and flushAndExit")
if "DesktopCLI.run" in main:
    raise SystemExit("PrimDesktopMain must not run DesktopCLI in a shell-exec process")
if main.find("flushAndExit") >= main.find("PrimApp.main()"):
    raise SystemExit("flushAndExit must happen before PrimApp.main()")
if "runHeadless" not in main:
    raise SystemExit("PrimDesktopMain must host --xpc-serve headless")
tramp = (root / "scripts/prims-desktop-trampoline.sh").read_text()
if "Contents/Helpers/prims-desktop" not in tramp or "exec " not in tramp:
    raise SystemExit("trampoline must exec the XPC client helper")
if "Contents/MacOS/Prim" in tramp:
    raise SystemExit("trampoline must not exec MacOS/Prim from a shell")
client = (root / "Sources/PrimsDesktopCLI/main.swift").read_text()
if "ChatDB" in client or "sqlite3_open" in client:
    raise SystemExit("PATH client must not open chat.db")
chatdb = (root / "Sources/PrimMacCore/ChatDB.swift").read_text()
if "isLaunchServicesAppProcess" not in chatdb:
    raise SystemExit("ChatDB must refuse shell-exec processes")
tcc = (root / "scripts/TCC.md").read_text()
if "LaunchServices" not in tcc or "XPC" not in tcc or "posix_spawn" not in tcc:
    raise SystemExit("TCC.md must lock LS type 0 / shell-exec type 1 / PATH is XPC")
if "in-app Messages" not in tcc:
    raise SystemExit("TCC.md must say FDA prove is the in-app Messages path")
if "doctor_chatdb_inherits_app_fda" in (root / "scripts/litmus.py").read_text():
    raise SystemExit("litmus must not treat piped doctor chat_db_readable as the FDA gate")
build = (root / "scripts/build.sh").read_text().replace("\\\n", " ")
if ".app.bak" in build:
    raise SystemExit("build.sh still mints bak apps")
for line in build.splitlines():
    s = line.strip()
    if s.startswith("#"):
        continue
    if "codesign" in s and "--deep" in s and "--verify" not in s:
        raise SystemExit(f"codesign --deep stomp: {s}")
if "--identifier" not in build or "sh.prims.desktop" not in build:
    raise SystemExit("build.sh must sign --identifier sh.prims.desktop")
print("ENTRY SOURCE OK")
PY

# Identity/TCC gates. Live Mac checks fail closed when the app is missing.
python3 "$ROOT/scripts/litmus.py" --pro
python3 "$ROOT/scripts/litmus.py" --deep

if ! command -v prims-desktop >/dev/null 2>&1; then
  echo "prims-desktop not on PATH — install with ./scripts/install-cli.sh" >&2
  exit 1
fi

python3 "$ROOT/scripts/litmus.py"
prims-desktop asmp
prims-desktop doctor
prims-desktop connectors
prims-desktop status imessage-chatdb-receive

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
    --filter HostTests.testASMPConnectorManifestIsAServiceNotAPackType \
    --filter HostTests.testProductIdentityIsLocked \
    --filter HostTests.testInfoPlistAndPPPCAreBound \
    --filter HostTests.testSourcesDoNotAskFDAForLooseCLI \
    --filter HostTests.testProcessEntryRoutesEveryDesktopCLIVerb \
    --filter HostTests.testCLIEntryIsProcessMainNotSwiftUIInit \
    --filter HostTests.testBuildScriptDoesNotDeepStompIdentifiers \
    --filter HostTests.testTrampolineAndInstallCLIExecAppExecutable \
    --filter HostTests.testFDAProveIsInAppMessagesNotPipedDoctor
else
  echo "skip swift test (../prim-sim missing)"
fi

echo "PROVE OK"
