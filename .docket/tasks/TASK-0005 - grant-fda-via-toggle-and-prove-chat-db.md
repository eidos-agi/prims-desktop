---
id: TASK-0005
title: Prove chat.db readable under the existing FDA grant
status: In Progress
created: '2026-08-27'
priority: high
milestone: MS-0002
tags:
  - ship
  - fda
acceptance-criteria:
  - FDA stays on Prims Desktop.app (sh.prims.desktop). Do not ask Daniel to toggle again.
  - PATH prims-desktop doctor shows chat.db readable via sqlite open, not a heuristic
  - Running principal is Contents/MacOS/Prim (client_type 0), not Contents/Helpers/prims-desktop
  - Do not grant FDA to a helper path
  - PPPC mobileconfig is not installed
  - 'User copy stays: Prims Desktop needs Full Disk Access to read Messages on this Mac.'
definition-of-done:
  - prims-desktop doctor prints chat.db readable
  - No window opens for doctor/status/receive/connectors/asmp/config
  - User never saw ~/.local/bin in the grant copy
updated: '2026-08-27'
dependencies:
  - TASK-0014
  - TASK-0018
---
FDA was never granted. Consumer path is the Full Disk Access toggle for Prims Desktop. Do not install deploy/prims-desktop.fulldisk.mobileconfig (PayloadRemovalDisallowed=true). Trampoline at ~/.local/bin/prims-desktop is a script; TCC client is the app.

FDA is already granted (2026-08-27). Same Identifier on a helper is not enough. Shell-exec helper = client_type 1. App bundle = client_type 0. Prove through MacOS/Prim. Disable leftover Prim.app.bak-20260820-022359 in the FDA list.
