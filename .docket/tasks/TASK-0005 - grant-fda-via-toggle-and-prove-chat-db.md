---
id: TASK-0005
title: Grant FDA via toggle and prove chat.db
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0001
tags:
  - ship
  - fda
acceptance-criteria:
  - 'User copy is exactly: Prims Desktop needs Full Disk Access to read Messages on this Mac.'
  - FDA is granted to Prims Desktop.app (sh.prims.desktop), never to ~/.local/bin
  - prims-desktop doctor / status can read chat.db through Contents/Helpers
  - PPPC mobileconfig is not installed
definition-of-done:
  - chat.db is not locked
  - User never saw ~/.local/bin in the grant copy
---
FDA was never granted. Consumer path is the Full Disk Access toggle for Prims Desktop. Do not install deploy/prims-desktop.fulldisk.mobileconfig (PayloadRemovalDisallowed=true). Trampoline at ~/.local/bin/prims-desktop is a script; TCC client is the app.
