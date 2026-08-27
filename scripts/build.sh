#!/bin/bash
# Assemble /Applications/Prims Desktop.app and sign it as a company app.
# ChatDB + CLI live in Contents/Helpers so they inherit the app's FDA.
# This VM cannot codesign. Run on the Mac that has the Developer ID identity.
set -eo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
APP="/Applications/Prims Desktop.app"
BIN="$PKG/.build/release/PrimMac"
CLI="$PKG/.build/release/prims-desktop"
CHATDB="$PKG/.build/release/imessage-chatdb-receive"
TEAM="Y6CQ4SWPWM"
IDENTITY="Developer ID Application: Eidos AGI LLC ($TEAM)"

cd "$PKG"
rm -f "$BIN" "$CLI" "$CHATDB"
swift build -c release --product PrimMac
swift build -c release --product prims-desktop
swift build -c release --product imessage-chatdb-receive

osascript -e 'quit app "Prims Desktop"' 2>/dev/null || true
osascript -e 'quit app "Prim"' 2>/dev/null || true
pkill -f "Prims Desktop.app/Contents/MacOS/Prim" 2>/dev/null || true
pkill -f "Prims Desktop.app/Contents/Helpers/prims-desktop" 2>/dev/null || true
sleep 0.4

if [[ -d "$APP" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  cp -R "$APP" "/Applications/Prims Desktop.app.bak-$stamp"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp "$BIN" "$APP/Contents/MacOS/Prim"
cp "$CLI" "$APP/Contents/Helpers/prims-desktop"
cp "$CHATDB" "$APP/Contents/Helpers/imessage-chatdb-receive"
chmod 755 "$APP/Contents/MacOS/Prim" \
  "$APP/Contents/Helpers/prims-desktop" \
  "$APP/Contents/Helpers/imessage-chatdb-receive"
cp "$PKG/Info.plist" "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

security find-certificate -c "$IDENTITY" >/dev/null 2>&1 || {
  echo "FATAL: $IDENTITY not in keychain — refusing to sign Prims Desktop.app." >&2
  echo "This Mac still has to: sign, codesign -dr for CodeRequirement, notarize, copy app to /Applications, install trampoline." >&2
  exit 1
}

codesign --force --options runtime --timestamp \
  --entitlements "$PKG/Prim.entitlements" \
  --sign "$IDENTITY" \
  "$APP/Contents/Helpers/imessage-chatdb-receive" \
  "$APP/Contents/Helpers/prims-desktop" \
  "$APP/Contents/MacOS/Prim"

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
echo "helpers $APP/Contents/Helpers/prims-desktop"
echo "helpers $APP/Contents/Helpers/imessage-chatdb-receive"
echo "next: codesign -dr - \"$APP\"  → fill deploy/prims-desktop.fulldisk.mobileconfig CodeRequirement"
echo "next: notarize, then ./scripts/install-cli.sh"
