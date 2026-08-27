---
id: TASK-0018
title: PATH trampoline execs Contents/MacOS/Prim
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0002
tags:
  - ship
  - tcc
  - cli
acceptance-criteria:
  - scripts/prims-desktop-trampoline.sh execs /Applications/Prims Desktop.app/Contents/MacOS/Prim with the user argv
  - install-cli.sh installs that trampoline and does not codesign the script
  - PATH prims-desktop never execs Contents/Helpers/prims-desktop
  - Helpers may remain for in-app spawn only
definition-of-done:
  - which prims-desktop is a script
  - script exec target is MacOS/Prim
---
PATH is the app executable. That is the company pattern. Helpers are not TCC clients.
