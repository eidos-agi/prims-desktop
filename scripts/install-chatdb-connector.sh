#!/bin/bash
# Compile chatdb-extract (eidos-do-v1) + Prim Tool wrapper; merge local overlay.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.local/bin"
EXTRACT_SRC="$HOME/repos-eidos-agi/eidos-do-v1/tools/chatdb-extract.swift"
WRAP_SRC="$ROOT/tools/imessage-chatdb-receive.swift"
IDENTITY="Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)"
OVERLAY="$HOME/.prim/registry.local.json"

mkdir -p "$DEST" "$HOME/.prim"

if [[ ! -f "$EXTRACT_SRC" ]]; then
  echo "FATAL: missing $EXTRACT_SRC — reuse eidos-do-v1, do not rewrite the decoder." >&2
  exit 1
fi

swiftc -O -o "$DEST/chatdb-extract" "$EXTRACT_SRC" -framework AppKit -lsqlite3
swiftc -O -o "$DEST/imessage-chatdb-receive" "$WRAP_SRC"

security find-certificate -c "$IDENTITY" >/dev/null 2>&1 || {
  echo "FATAL: $IDENTITY not in keychain." >&2
  exit 1
}
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$DEST/chatdb-extract"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$DEST/imessage-chatdb-receive"

python3 - <<'PY'
import json
from pathlib import Path
path = Path.home() / ".prim" / "registry.local.json"
doc = {"version": 1, "types": [], "tools": []}
if path.exists():
    doc = json.loads(path.read_text())
tools = [t for t in doc.get("tools", []) if t.get("name") != "imessage-chatdb-receive"]
tools.append({
    "name": "imessage-chatdb-receive",
    "kind": "connector",
    "direction": "receive",
    "cites": "*",
    "as": "chatdb-sqlite",
    "bin": "imessage-chatdb-receive",
    "repo": "local",
})
doc["version"] = doc.get("version") or 1
doc["types"] = doc.get("types") or []
doc["tools"] = tools
path.write_text(json.dumps(doc, indent=2) + "\n")
print(f"wrote {path} ({len(tools)} tools)")
PY

echo "installed $DEST/chatdb-extract"
echo "installed $DEST/imessage-chatdb-receive"
