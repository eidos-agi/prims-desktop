# prims-desktop

GitHub: https://github.com/eidos-agi/prims-desktop

Local tree: `~/repos-eidos-agi/prims-desktop` (this repo).

App: `/Applications/Prims Desktop.app`  
Identifier: `sh.prims.desktop`  
Pack UTI: `com.eidosagi.prim` (not the app id)  
CLI: `prims-desktop` — PATH trampoline that execs `Contents/MacOS/Prim` (`./scripts/install-cli.sh`). See `scripts/TCC.md`.

ASMP: `prims-desktop asmp` announces live connectors; health is `http://127.0.0.1:7749/health`.

Prove (agents): `./scripts/prove.sh`  
Adversarial gate: `./scripts/litmus.py` (asked-for / naming / pro / deep).

Mac host for Prim packs and Prim Tool connectors. Connectors + CLI are the product. The window is secondary.

Signed `Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)`.

Prims Desktop needs Full Disk Access to read Messages on this Mac.

```bash
./scripts/prove.sh
./scripts/build.sh
./scripts/install-cli.sh
open -a "Prims Desktop"
prims-desktop doctor
```
