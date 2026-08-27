---
id: TASK-0012
title: Implement prims-connectors-paseo
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0001
tags:
  - ship
  - connector
acceptance-criteria:
  - One connector, cell catalog, not gmw-only
  - Lives under Connectors, not a fourth sidebar door
  - Native paseo <verb> --json --host host:port
  - No docker exec
  - 'V1 verbs: cells, health, ls, inspect, send --no-wait, logs (no --follow)'
  - 'Out of v1: run/clone, delete/archive, daemon lifecycle, recreate, Volta move, permit allow/deny'
  - 'Known cells stay: laptop :6767, paseo-eidos :16767, paseo-gmw :16768, paseo-arp :16769, paseo-aic :16770, paseo-reeves :16771, paseo-prims :16777'
  - GMW prove agent 102adae1-a260-47dc-b8b1-087cfed7aff3, send --no-wait
  - Laptop :6767 is local; remotes via connector-owned SSH LocalForward (hostkey 127.0.0.1 only). SSH down = remotes dark
definition-of-done:
  - New Paseo is a catalog row, not a new connector
updated: '2026-08-27'
---
Daniel via Cerebroski. Not Volta, not Kai. Do not recreate cells.

Cerebroski prove 2026-08-27 on this Mac: viable. Verbs are not the risk. Reach is.

Laptop :6767 already answers locally. All six remote cells /api/health 200 on hostkey (eidos 16767, gmw 16768, arp 16769, aic 16770, reeves 16771, prims 16777). Those ports are 127.0.0.1 only — this Mac cannot see :16768 without a tunnel. hostkey has no paseo binary. No LocalForward in ssh config today. ControlMaster already on Host hostkey.

Proof: ssh -L 26768:127.0.0.1:16768 hostkey, then Mac paseo 0.6.1 --host 127.0.0.1:26768 listed GMW agents and inspected 102adae1 (idle, claude, /workspace/greenmark-cockpit). Tunnel torn down after. Version skew 0.6.1 CLI → 0.5.1 daemon is fine for ls/inspect. Did not fire send.

Product path: Mac paseo --host plus connector-owned SSH forwards (or on-demand mux). Not docker exec. Not a new connector per cell. SSH down = all remotes dark. Permission cards still break blocking send — v1 send stays --no-wait.
