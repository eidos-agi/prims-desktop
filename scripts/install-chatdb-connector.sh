#!/bin/bash
# Point the local overlay at the in-bundle chat.db helper.
# Does not install a loose ~/.local/bin ChatDB binary.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="/Applications/Prims Desktop.app"
HELPER="$APP/Contents/Helpers/imessage-chatdb-receive"
OVERLAY="$HOME/.prim/registry.local.json"

if [[ ! -x "$HELPER" ]]; then
  echo "FATAL: in-bundle helper missing at $HELPER" >&2
  echo "Assemble and sign the app first: ./scripts/build.sh" >&2
  exit 1
fi

mkdir -p "$HOME/.prim"

python3 - <<PY
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

echo "helper    $HELPER"
echo "Prims Desktop needs Full Disk Access to read Messages on this Mac."
