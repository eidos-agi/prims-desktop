---
id: TASK-0013
title: Litmus and prove green
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0001
tags:
  - ship
  - prove
acceptance-criteria:
  - ./scripts/litmus.py --asked --naming --pro --deep is green
  - ./scripts/prove.sh is green
  - No screenshot CI
  - Prove stays on this Mac
definition-of-done:
  - Ship leftovers cannot close while litmus is red
---
Last full run was about 53 pass / 12 fail. GitHub Actions will not sign or read chat.db.
