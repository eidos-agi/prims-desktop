#!/bin/bash
# Assemble /Applications/Prims Desktop.app and sign it as a company app.
# PATH CLI execs Contents/MacOS/Prim (bundle executable, TCC client_type 0).
# Helpers stay inside the bundle for in-app spawn only — do not exec them from a shell.
# Never codesign --deep the .app (that resets nested Identifier to the Mach-O filename).
# Never leave /Applications/*.bak* — those are TCC ghosts.
# This VM cannot codesign. Run on the Mac that has the Developer ID identity.
set -eo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
APP="/Applications/Prims Desktop.app"
BIN="$PKG/.build/release/PrimMac"
CLI="$PKG/.build/release/prims-desktop"
CHATDB="$PKG/.build/release/imessage-chatdb-receive"
TEAM="Y6CQ4SWPWM"
BUNDLE_ID="sh.prims.desktop"
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

STAGE_ROOT="$(mktemp -d /tmp/prims-desktop-stage.XXXXXX)"
STAGE="$STAGE_ROOT/Prims Desktop.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" "$STAGE/Contents/Helpers"
cp "$BIN" "$STAGE/Contents/MacOS/Prim"
cp "$CLI" "$STAGE/Contents/Helpers/prims-desktop"
cp "$CHATDB" "$STAGE/Contents/Helpers/imessage-chatdb-receive"
chmod 755 "$STAGE/Contents/MacOS/Prim" \
  "$STAGE/Contents/Helpers/prims-desktop" \
  "$STAGE/Contents/Helpers/imessage-chatdb-receive"
cp "$PKG/Info.plist" "$STAGE/Contents/Info.plist"
echo -n "APPL????" > "$STAGE/Contents/PkgInfo"

security find-certificate -c "$IDENTITY" >/dev/null 2>&1 || {
  echo "FATAL: $IDENTITY not in keychain — refusing to sign Prims Desktop.app." >&2
  echo "This Mac still has to: sign, codesign -dr for CodeRequirement, notarize, copy app to /Applications, install trampoline." >&2
  rm -rf "$STAGE_ROOT"
  exit 1
}

sign_identity() {
  codesign --force --options runtime --timestamp \
    --identifier "$BUNDLE_ID" \
    --entitlements "$PKG/Prim.entitlements" \
    --sign "$IDENTITY" \
    "$1"
}

# Inner binaries first, same Identifier as the app. Then seal the bundle.
# Do not codesign --deep — that stomps nested Identifier to the filename.
sign_identity "$STAGE/Contents/Helpers/imessage-chatdb-receive"
sign_identity "$STAGE/Contents/Helpers/prims-desktop"
sign_identity "$STAGE/Contents/MacOS/Prim"
sign_identity "$STAGE"

actual="$(codesign -dv --verbose=4 "$STAGE" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
if [[ "$actual" != "$TEAM" ]]; then
  echo "FATAL: TeamIdentifier is '$actual', expected $TEAM" >&2
  rm -rf "$STAGE_ROOT"
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "$STAGE"

REPLACED_ROOT=""
if [[ -d "$APP" ]]; then
  REPLACED_ROOT="$(mktemp -d /tmp/prims-desktop-replaced.XXXXXX)"
  mv "$APP" "$REPLACED_ROOT/Prims Desktop.app"
fi
mkdir -p "$(dirname "$APP")"
mv "$STAGE" "$APP"
rm -rf "$STAGE_ROOT"
if [[ -n "$REPLACED_ROOT" ]]; then
  rm -rf "$REPLACED_ROOT"
fi

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
echo "principal $APP/Contents/MacOS/Prim"
echo "helpers $APP/Contents/Helpers/prims-desktop (PATH XPC client — does not open chat.db)"
echo "helpers $APP/Contents/Helpers/imessage-chatdb-receive (in-app spawn only — do not exec from PATH)"
echo "next: ./scripts/install-cli.sh"
echo "do not install deploy/prims-desktop.fulldisk.mobileconfig"
echo "do not grant FDA to a helper path"
