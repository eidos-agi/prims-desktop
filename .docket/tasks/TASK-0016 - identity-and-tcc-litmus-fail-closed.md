---
id: TASK-0016
title: Identity and TCC litmus fail-closed
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0002
tags:
  - ship
  - prove
acceptance-criteria:
  - PATH script exec target is Contents/MacOS/Prim
  - That Prim Identifier=sh.prims.desktop, Info.plist bound, DR matches the .app
  - Prim doctor does not start NSApplication
  - doctor.chat_db_readable false is a fail when the running principal is the app (FDA already granted)
  - build.sh cannot --deep-stomp identifiers
  - Leftover ~/Applications/Prims Desktop.app or /Applications/*.bak* fail
  - User copy never mentions ~/.local/bin
  - Bundle id stays sh.prims.desktop; pack UTI stays com.eidosagi.prim
definition-of-done:
  - ./scripts/litmus.py --deep fails any of the above
  - No skip that hides a split principal
---
Daniel: tests so this never fucks up. Fail closed. Do not skip as FDA not granted if Identifier is not the app.
