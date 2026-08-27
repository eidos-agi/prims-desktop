---
id: TASK-0003
title: Retire leftover ~/Applications/Prims Desktop.app
status: To Do
created: '2026-08-27'
priority: medium
milestone: MS-0001
tags:
  - ship
  - leftover
acceptance-criteria:
  - ~/Applications/Prims Desktop.app is gone
  - ~/Applications/Prim.app.bak-* is gone
  - Live app is only /Applications/Prims Desktop.app (sh.prims.desktop)
  - litmus fails if the leftover or bak family returns
definition-of-done:
  - One signed app, in /Applications
updated: '2026-08-27'
---
Old Aug 26 copy still sits in ~/Applications. Live identity is /Applications. Do not keep two apps that look the same.

Audit 2026-08-27: leftover ~/Applications/Prims Desktop.app is Identifier com.eidosagi.prim (signed Aug 26). Also 27 ~/Applications/Prim.app.bak-* all com.eidosagi.prim, including Prim.app.bak-20260820-022359 which still has FDA ON. Those are a different TCC client than live sh.prims.desktop. Retire the live leftover and the bak family. Do not leave build.sh snapshots in /Applications.
