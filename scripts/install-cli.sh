#!/bin/bash
# Install a PATH trampoline that execs the in-bundle XPC client helper.
# Does not copy ChatDB. Does not sign the PATH trampoline as a TCC principal.
# Never exec Contents/MacOS/Prim from PATH (shell-exec is TCC client_type 1).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(realpath "$ROOT")"
DEST="$HOME/.local/bin"
APP="/Applications/Prims Desktop.app"
CLIENT="$APP/Contents/Helpers/prims-desktop"
TRAMPOLINE="$ROOT/scripts/prims-desktop-trampoline.sh"

if [[ ! -x "$CLIENT" ]]; then
  echo "FATAL: XPC client missing at $CLIENT" >&2
  echo "Assemble and sign the app first: ./scripts/build.sh" >&2
  exit 1
fi
if [[ ! -f "$TRAMPOLINE" ]]; then
  echo "FATAL: missing $TRAMPOLINE" >&2
  exit 1
fi

mkdir -p "$DEST"
# Replace a leftover Mach-O TCC client with the trampoline.
rm -f "$DEST/prims-desktop"
cp "$TRAMPOLINE" "$DEST/prims-desktop"
chmod 755 "$DEST/prims-desktop"
ln -sfn prims-desktop "$DEST/prim-desktop"

# Comments may mention chat.db. Only live lines are the gate.
if grep -v '^[[:space:]]*#' "$DEST/prims-desktop" | grep -q 'ChatDB\|chat\.db\|sqlite3_open'; then
  echo "FATAL: trampoline must not contain ChatDB read code" >&2
  exit 1
fi
if grep -q 'Contents/MacOS/Prim' "$DEST/prims-desktop"; then
  echo "FATAL: trampoline must not exec Contents/MacOS/Prim from a shell" >&2
  exit 1
fi
if ! grep -q 'Contents/Helpers/prims-desktop' "$DEST/prims-desktop"; then
  echo "FATAL: trampoline must exec the XPC client helper" >&2
  exit 1
fi
if file "$DEST/prims-desktop" | grep -qi 'Mach-O'; then
  echo "FATAL: ~/.local/bin/prims-desktop is a Mach-O — it must be a trampoline script" >&2
  exit 1
fi

echo "installed trampoline $DEST/prims-desktop"
echo "execs     $CLIENT  (XPC client — does not open chat.db)"
echo "linked    $DEST/prim-desktop -> prims-desktop"
