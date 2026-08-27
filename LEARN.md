# Learn loop

Repeats until `scripts/learn` reports **≥ 90** on `GREAT.md`, or telos says
`stop`. One ceremony: score → do the next gap → prove in Prim.app → tick.

```bash
cd /Users/dshanklinbv/repos-eidos-agi/prims-desktop
lessons-md project-set .
./scripts/learn                  # writes .learn/LATEST.json + next gap
./scripts/capture-window         # Prim.app window PNG into .learn/proofs/
# do LATEST.next.action
# inspect the PNG (Read it). Update .learn/observations.json from what you SAW.
./scripts/learn
telos-md tick --north-star-id "$(python3 -c 'import json;print(json.load(open(".learn/north-star.json"))["north_star_id"])')" \
  --action-summary "…" \
  --measurement "$(python3 -c 'import json;print(json.load(open(".learn/LATEST.json"))["score"])')" \
  --repo-path "$(pwd)" --json
# read signal: continue → next gap; pivot → integrate; stop → checkpoint
```

North star id lives in `.learn/north-star.json`. Charter metric is
`great_score` / 90.

## One iteration

1. `./scripts/learn` — honest score, largest remaining gap is `next`.
2. Build **only that gap**.
3. Prove it: HostTests when code changed; **Prim.app window** via
   `scripts/capture-window` (or `screencapture -l <windowid>`) when UI
   changed. Read the PNG. Do not score Paseo HTML as the app.
4. Backup `/Applications/Prims Desktop.app` with a timestamp before overwrite;
   `scripts/build.sh` is the ship identity.
5. `secondlook-md look --topic "<the gap>"` after a non-trivial change.
6. Update `ACCEPTANCE.md` — never batch-✅.
7. `telos-md tick` with the new `great_score`. Obey `signal`.
8. Repeat.

## Stops

- Score ≥ 90 and remaining gaps are notarize / Mail / Messages.
- Telos `stop` or three zero-delta ticks.
- Pivot: stop adding parallel pieces; wire what already works into the
  real window.

## Do not

- Treat `http://127.0.0.1:8799` as Prim.app.
- Claim Save writes mutations without an in-app proof.
- Hand-write `.testr/test-attempts` or `.shipr/release-attempts`.
- Grind past `stop`.
