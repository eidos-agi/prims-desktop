# prims-desktop

GitHub: https://github.com/eidos-agi/prims-desktop

Local tree: `~/repos-eidos-agi/prim-mac-v1`.

Prove (agents): `./scripts/prove.sh`

# prim-mac-v1

Mac document host for Prim.app (**v1**). Frozen line so **prim-mac-v2** can rebuild beside it.

Path: `~/repos-eidos-agi/prim-mac-v1` (was `prim-mac`).

This is how a `.prim` opens on a Mac.

Double-click the file. The host reads the category registry, detects the type, and runs a citing tool. File → Save writes that pack. Prim.app is not the file and not a canonical UI.

Registered as `prim-mac`: surface / talk / `as: host` / cites `*`.

Signed `Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)`. Local Dev is not the ship identity. Notarize before it leaves this Mac.

```bash
"$HOME/go/bin/testr" model --project . --json
swift test --filter HostTests
"$HOME/go/bin/testr" attempt --goal "…" --status passed --proof "…"
"$HOME/go/bin/shipr" model --project . --json
./scripts/build.sh
"$HOME/go/bin/shipr" attempt --goal "…" --status blocked --notes "unnotarized"
open -a Prim ~/repos-eidos-agi/prim-web/demo/docket/intent.emf.prim
./scripts/learn
```

World-class target is `GREAT.md` (90/100). The repeating loop is `LEARN.md`.
