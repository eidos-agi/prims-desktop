#!/bin/bash
# Install a PATH trampoline that execs the bundle executable (MacOS/Prim).
# Does not copy ChatDB. Does not sign the PATH trampoline as a TCC principal.
# Never exec Contents/Helpers/prims-desktop from PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(realpath "$ROOT")"
DEST="$HOME/.local/bin"
APP="/Applications/Prims Desktop.app"
PRIM="$APP/Contents/MacOS/Prim"
TRAMPOLINE="$ROOT/scripts/prims-desktop-trampoline.sh"

if [[ ! -x "$PRIM" ]]; then
  echo "FATAL: app executable missing at $PRIM" >&2
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

if grep -q 'ChatDB\|chat\.db\|sqlite3_open' "$DEST/prims-desktop"; then
  echo "FATAL: trampoline must not contain ChatDB read code" >&2
  exit 1
fi
if grep -q 'Contents/Helpers/prims-desktop' "$DEST/prims-desktop"; then
  echo "FATAL: trampoline must not exec Contents/Helpers/prims-desktop" >&2
  exit 1
fi
if ! grep -q 'Contents/MacOS/Prim' "$DEST/prims-desktop"; then
  echo "FATAL: trampoline must exec Contents/MacOS/Prim" >&2
  exit 1
fi
if file "$DEST/prims-desktop" | grep -qi 'Mach-O'; then
  echo "FATAL: ~/.local/bin/prims-desktop is a Mach-O — it must be a trampoline script" >&2
  exit 1
fi

echo "installed trampoline $DEST/prims-desktop"
echo "execs     $PRIM"
echo "linked    $DEST/prim-desktop -> prims-desktop"
