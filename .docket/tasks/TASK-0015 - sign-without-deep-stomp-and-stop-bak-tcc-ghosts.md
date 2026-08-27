---
id: TASK-0015
title: Sign without --deep stomp and stop bak TCC ghosts
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0002
tags:
  - ship
  - sign
acceptance-criteria:
  - build.sh does not codesign --deep in a way that resets nested Identifier to the Mach-O filename
  - App + MacOS/Prim Identifier=sh.prims.desktop, Team Y6CQ4SWPWM, hardened runtime, bound Info.plist
  - No /Applications/Prims Desktop.app.bak-* left as the success path
  - ~/Applications/Prims Desktop.app is gone (TASK-0003)
  - Leftover Prim.app.bak-20260820-022359 is not an FDA client
definition-of-done:
  - A rebuild cannot mint a second TCC principal
---
Live proof 2026-08-27: --deep reset helper Identifier to prims-desktop. bak copies in /Applications showed up in Full Disk Access.
