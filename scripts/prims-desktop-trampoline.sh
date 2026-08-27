#!/bin/sh
# PATH trampoline. Exec the helper inside Prims Desktop.app.
# Not a TCC principal. Contains no reader.
set -e
HELPER="/Applications/Prims Desktop.app/Contents/Helpers/prims-desktop"
if [ ! -x "$HELPER" ]; then
  echo "prims-desktop: helper missing at $HELPER — assemble the app with ./scripts/build.sh" >&2
  exit 127
fi
exec "$HELPER" "$@"
