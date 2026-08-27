# TCC / FDA — Prims Desktop

Locked 2026-08-27. Next agent must not "fix" FDA by resigning `Contents/Helpers/`.

## The model

| Principal | How it is launched | TCC `client_type` | FDA |
|-----------|--------------------|-------------------|-----|
| `/Applications/Prims Desktop.app` / `Contents/MacOS/Prim` | Finder, `open -a`, or PATH trampoline `exec` of this Mach-O | **0** (app bundle) | The grant Daniel already made. |
| `Contents/Helpers/prims-desktop` or `imessage-chatdb-receive` | `exec` from a shell / PATH script | **1** (command-line client) | **Does not inherit** the app grant. Same Identifier is not enough. |
| `~/.local/bin/prims-desktop` | PATH script | not a principal | Must stay a trampoline. Never codesign it. |

`codesign --identifier sh.prims.desktop` on a helper does not make a shell-exec'd Mach-O into the app. `doctor` opens `~/Library/Messages/chat.db` via `sqlite3_open_v2` in the running process (`ChatDB.health()`). If that process is a helper, chat.db stays locked.

## PATH

`scripts/prims-desktop-trampoline.sh` must:

```
exec "/Applications/Prims Desktop.app/Contents/MacOS/Prim" "$@"
```

`PrimDesktopMain` (`@main`) sees a CLI verb and calls `DesktopCLI.run` then `_exit` **before** `PrimApp.main()` / `NSApplication`. Empty argv (double-click / `open -a`) is the glass.

Do not use `~/Applications/Prims Desktop.app`. Do not leave `/Applications/Prims Desktop.app.bak*` or `Prim.app.bak*` — leftover `.app` bundles are TCC ghosts (one already has FDA ON).

## Sign

- Identifier stays `sh.prims.desktop`. Pack UTI stays `com.eidosagi.prim`.
- Team `Y6CQ4SWPWM`. Hardened runtime. Bound Info.plist on `MacOS/Prim`.
- `build.sh` signs inner binaries with `--identifier sh.prims.desktop` and seals the `.app` **without** `--deep`. `--deep` resets nested Identifier to the Mach-O filename (`prims-desktop`, `imessage-chatdb-receive`).
- Helpers may remain for in-app spawn. Do not exec them from PATH. Do not ask for a second FDA grant. Do not grant FDA to a helper path. Do not install `deploy/prims-desktop.fulldisk.mobileconfig`.
