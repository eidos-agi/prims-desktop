# prims-desktop

GitHub: https://github.com/eidos-agi/prims-desktop

Local tree: `~/repos-eidos-agi/prims-desktop` (this repo).

App: `~/Applications/Prims Desktop.app`  
CLI: `prims-desktop` (`./scripts/install-cli.sh`)

ASMP: `prims-desktop asmp` announces live connectors; health is `http://127.0.0.1:7749/health`.

Prove (agents): `./scripts/prove.sh`  
Adversarial gate: `./scripts/litmus.py` (asked-for / naming / pro).

Mac host for Prim packs and Prim Tool connectors. Connectors + CLI are the product. The window is secondary.

Signed `Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)`.

```bash
./scripts/prove.sh
./scripts/build.sh
open -a "Prims Desktop"
prims-desktop doctor
```
