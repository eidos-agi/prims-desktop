#!/bin/bash
# Install a PATH trampoline that execs the in-bundle CLI helper.
# Does not copy ChatDB. Does not sign the PATH trampoline as a TCC principal.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(realpath "$ROOT")"
DEST="$HOME/.local/bin"
APP="/Applications/Prims Desktop.app"
HELPER="$APP/Contents/Helpers/prims-desktop"
TRAMPOLINE="$ROOT/scripts/prims-desktop-trampoline.sh"

if [[ ! -x "$HELPER" ]]; then
  echo "FATAL: in-bundle CLI missing at $HELPER" >&2
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
if file "$DEST/prims-desktop" | grep -qi 'Mach-O'; then
  echo "FATAL: ~/.local/bin/prims-desktop is a Mach-O — it must be a trampoline script" >&2
  exit 1
fi

echo "installed trampoline $DEST/prims-desktop"
echo "execs     $HELPER"
echo "linked    $DEST/prim-desktop -> prims-desktop"
