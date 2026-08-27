---
id: TASK-0001
title: App icon and CFBundleIconFile
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0001
tags:
  - ship
  - brand
acceptance-criteria:
  - Info.plist has CFBundleIconFile
  - /Applications/Prims Desktop.app/Contents/Resources is not empty
  - Dock and About show the icon
  - litmus checks the icon bind
definition-of-done:
  - Signed app in /Applications shows a real icon
  - No empty Resources leftover
---
Resources is empty. Product, Dock, and About are Prims Desktop but there is no icon. Do not ship a placeholder that looks like a lab mark.
