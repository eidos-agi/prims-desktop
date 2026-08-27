---
id: TASK-0017
title: Write the TCC model in-repo
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0002
tags:
  - ship
  - tcc
  - docs
acceptance-criteria:
  - Short in-repo note next to build.sh or in CHARTER
  - 'States: app bundle client_type 0 (FDA); shell-exec helper Mach-O client_type 1'
  - PATH must be the bundle executable
  - Next agent must not fix this by resigning Helpers/ or embedding helper Info.plist
  - Does not mention ~/.local/bin in any user-facing sentence
definition-of-done:
  - The next agent can read why PATH is MacOS/Prim without rediscovering it
---
Company-grade: the model is written down so we do not relitigate helper plists.
