---
id: TASK-0004
title: Notarize and staple Developer ID
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0001
tags:
  - ship
  - sign
acceptance-criteria:
  - spctl accepts the app (notarized Developer ID)
  - Ticket stapled on /Applications/Prims Desktop.app
  - notarytool profile exists on this Mac before anyone claims notarized
definition-of-done:
  - spctl no longer says Unnotarized Developer ID
---
Signed Developer ID Y6CQ4SWPWM, not notarized. Blocked until a notarytool keychain profile exists on this Mac. Notarize only if the binary leaves the Mac or Gatekeeper must accept a fresh download. Do not fake a staple.
