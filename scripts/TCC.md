# TCC / FDA — Prims Desktop

Locked 2026-08-27 (updated after Mac prove of PR 3). Next agent must not
"fix" FDA by resigning Helpers, embedding Info.plist on helpers, or
exec'ing `Contents/MacOS/Prim` from a shell.

## The model

| Principal | How it is launched | TCC `client_type` | FDA |
|-----------|--------------------|-------------------|-----|
| `/Applications/Prims Desktop.app` launched by LaunchServices (`open -a`, Finder, `NSWorkspace.openApplication`) | LS / launchd parent | **0** (app bundle) | The grant Daniel already made. This process opens `chat.db`. |
| `Contents/MacOS/Prim` posix_spawn/`exec`'d from a shell or PATH trampoline | command-line | **1** | **Locked.** Same Identifier `sh.prims.desktop` and Team `Y6CQ4SWPWM` is not enough. Proven 2026-08-27. |
| `Contents/Helpers/prims-desktop` | PATH trampoline `exec` | **1** | Must not open `chat.db`. It is the XPC **client**. |
| `~/.local/bin/prims-desktop` | PATH script | not a principal | Thin trampoline. Never codesign it. Never put sqlite in it. |

`ChatDB.health()` is `sqlite3_open_v2` on `~/Library/Messages/chat.db` in the running process. It is allowed only when argv0 is `Contents/MacOS/Prim` **and** the parent is `launchd`.

## PATH

PATH is XPC. `scripts/prims-desktop-trampoline.sh` must:

```
exec "/Applications/Prims Desktop.app/Contents/Helpers/prims-desktop" "$@"
```

That helper may LaunchServices-open the bundle or talk XPC. It must not
`sqlite3_open` `chat.db`. Do not exec `Contents/MacOS/Prim` from PATH and
expect FDA.

**FDA prove is the in-app Messages path** (Settings “Connected” / stage
transcript first rows) in the running `Prims Desktop.app`. Piped
`prims-desktop doctor --json` is not the acceptance test. CLI doctor may
echo what the app already opened, after the UI path works.

Do not use `~/Applications/Prims Desktop.app`. Do not leave
`/Applications/Prims Desktop.app.bak*` or `Prim.app.bak*`.

## Sign

- Identifier stays `sh.prims.desktop`. Pack UTI stays `com.eidosagi.prim`.
- Team `Y6CQ4SWPWM`. Hardened runtime. Bound Info.plist on the LS-launched app.
- `build.sh` signs inner binaries with `--identifier sh.prims.desktop` and seals the `.app` **without** `--deep`.
- Do not grant FDA to a helper path. Do not install `deploy/prims-desktop.fulldisk.mobileconfig`. Do not ask for a second FDA toggle.
