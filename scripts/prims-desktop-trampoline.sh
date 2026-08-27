#!/bin/sh
# PATH trampoline. Thin XPC client — does not open chat.db.
# Exec the in-bundle client helper. Never posix_spawn the bundle executable
# from a tty (that is TCC client_type 1 and stays locked). See scripts/TCC.md.
set -e
CLIENT="/Applications/Prims Desktop.app/Contents/Helpers/prims-desktop"
if [ ! -x "$CLIENT" ]; then
  echo "prims-desktop: XPC client missing at $CLIENT — assemble the app with ./scripts/build.sh" >&2
  exit 127
fi
exec "$CLIENT" "$@"
