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
definition-of-done:
  - New Paseo is a catalog row, not a new connector
---
Daniel via Cerebroski. Not Volta, not Kai. Do not recreate cells.
