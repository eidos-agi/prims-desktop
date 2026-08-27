#!/bin/sh
# PATH trampoline. Exec the bundle executable — TCC client_type 0.
# Never exec Contents/Helpers/* from PATH. Not a TCC principal. Contains no reader.
set -e
PRIM="/Applications/Prims Desktop.app/Contents/MacOS/Prim"
if [ ! -x "$PRIM" ]; then
  echo "prims-desktop: app executable missing at $PRIM — assemble the app with ./scripts/build.sh" >&2
  exit 127
fi
exec "$PRIM" "$@"
