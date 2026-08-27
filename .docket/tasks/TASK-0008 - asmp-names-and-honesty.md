---
id: TASK-0008
title: ASMP names and honesty
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0001
tags:
  - ship
  - asmp
acceptance-criteria:
  - ASMP announces only prims-connectors-imessage, prims-connectors-finance, prims-connectors-tasks or the locked replacement, prims-connectors-registry, prims-connectors-paseo
  - Does not announce prim-viewer or prim-viewer-webmcp as a Desktop connector
  - No shared fake HTTP :7749
  - status ok=true only when the bin and capability exist
  - caps_match=yes
definition-of-done:
  - litmus --asked / --naming / --deep pass the honesty gates
---
Current announce still uses old bare tool names; caps_match=no. Viewer is a surface. Do not invent service names. prims-connectors-tasks was the interview name for docket and is in question — do not cement it if Daniel parks it.
