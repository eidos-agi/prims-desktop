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

Team ID **Y6CQ4SWPWM**. Backup `~/Applications/Prims Desktop.app` before replace.

## Proof then ship

1. `testr model --project . --json`
2. Path-relevant `test_commands` only
3. `testr attempt`
4. `shipr model --project . --json`
5. `shipr attempt` — **blocked** until `spctl -a` accepts notarized Developer ID

## Autonomous prove

`./scripts/prove.sh` — CLI + HostTests. No AppleScript. No screenshots.
