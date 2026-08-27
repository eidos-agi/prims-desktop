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
  - Live app is only /Applications/Prims Desktop.app
  - litmus fails if the leftover returns
definition-of-done:
  - One signed app, in /Applications
---
Old Aug 26 copy still sits in ~/Applications. Live identity is /Applications. Do not keep two apps that look the same.
