# Prims Desktop — agent rules

**Prims Desktop** is an Eidos macOS desktop product. Shipping practice lives in
`eidos-desktop-app-builder`. Product code stays here.

Keyword **testr** / **shipr**: load the committed models in `.testr/` and
`.shipr/`. Never re-detect. Never hand-write attempt JSON. Use
`$HOME/go/bin/testr` and `$HOME/go/bin/shipr`.

## Identities

| Lane | Identity |
|------|----------|
| Company ship (default build) | `Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)` + notary |
| Forbidden | ad-hoc, Local Dev as ship, personal `LJWV44N8BF` |

Team ID **Y6CQ4SWPWM**. Identifier **sh.prims.desktop**. Stage the live app aside and delete after swap — do not leave `/Applications/*.bak*` (TCC ghosts). Pack UTI stays `com.eidosagi.prim`. PATH is an XPC client; only the LaunchServices-launched app opens `chat.db`. FDA prove is in-app Messages on the Connectors door (Connected / first rows), not piped `prims-desktop doctor`, and must not wait on XPC. Three doors: Viewer, Connectors, Chat. See `scripts/TCC.md`.

## Proof then ship

1. `testr model --project . --json`
2. Path-relevant `test_commands` only
3. `testr attempt`
4. `shipr model --project . --json`
5. `shipr attempt` — **blocked** until `spctl -a` accepts notarized Developer ID

## Autonomous prove

`./scripts/prove.sh` — CLI + ASMP announce + path-relevant HostTests. No AppleScript. No screenshots.
