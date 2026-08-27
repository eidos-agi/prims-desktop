#!/bin/bash
# Assemble Prims Desktop.app and sign it as a company app: Eidos AGI LLC Developer ID.
set -eo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Applications/Prims Desktop.app"
BIN="$PKG/.build/release/PrimMac"
TEAM="Y6CQ4SWPWM"
IDENTITY="Developer ID Application: Eidos AGI LLC ($TEAM)"

cd "$PKG"
rm -f "$BIN"
swift build -c release --product PrimMac

osascript -e 'quit app "Prims Desktop"' 2>/dev/null || true
osascript -e 'quit app "Prim"' 2>/dev/null || true
pkill -f "Prims Desktop.app/Contents/MacOS/Prim" 2>/dev/null || true
pkill -f "Prims Desktop.app/Contents/MacOS/Prim" 2>/dev/null || true
sleep 0.4

if [[ -d "$APP" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  cp -R "$APP" "$HOME/Applications/Prims Desktop.app.bak-$stamp"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Prim"
cp "$PKG/Info.plist" "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

security find-certificate -c "$IDENTITY" >/dev/null 2>&1 || {
  echo "FATAL: $IDENTITY not in keychain — refusing to sign Prims Desktop.app." >&2
  exit 1
}

codesign --force --deep --options runtime --timestamp \
  --entitlements "$PKG/Prim.entitlements" \
  --sign "$IDENTITY" "$APP"

actual="$(codesign -dv --verbose=4 "$APP" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
if [[ "$actual" != "$TEAM" ]]; then
  echo "FATAL: TeamIdentifier is '$actual', expected $TEAM" >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP"
fi
if command -v duti >/dev/null 2>&1; then
  duti -s com.eidosagi.prim .prim all
fi

echo "built $APP"
