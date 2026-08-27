#!/bin/bash
# Build, Developer ID sign, and install prims-desktop to ~/.local/bin.
# Does not rebuild Prims Desktop.app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.local/bin"
TEAM="Y6CQ4SWPWM"
IDENTITY="Developer ID Application: Eidos AGI LLC ($TEAM)"

cd "$ROOT"
swift build -c release --product prims-desktop
BIN="$ROOT/.build/release/prims-desktop"

mkdir -p "$DEST"
cp "$BIN" "$DEST/prims-desktop"

security find-certificate -c "$IDENTITY" >/dev/null 2>&1 || {
  echo "FATAL: $IDENTITY not in keychain." >&2
  exit 1
}
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$DEST/prims-desktop"

actual="$(codesign -dv --verbose=4 "$DEST/prims-desktop" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
if [[ "$actual" != "$TEAM" ]]; then
  echo "FATAL: TeamIdentifier is '$actual', expected $TEAM" >&2
  exit 1
fi

ln -sfn prims-desktop "$DEST/prim-desktop"
echo "installed $DEST/prims-desktop"
echo "linked    $DEST/prim-desktop -> prims-desktop"
