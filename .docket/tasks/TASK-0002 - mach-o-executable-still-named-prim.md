---
id: TASK-0002
title: Mach-O executable still named Prim
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0001
tags:
  - ship
  - identity
acceptance-criteria:
  - CFBundleExecutable and the Mach-O name match the product or are documented as a locked exception
  - Package.swift / product names do not leak PrimMac or Prim.app as the live product
  - codesign -dr still Identifier=sh.prims.desktop Team Y6CQ4SWPWM
definition-of-done:
  - No leftover Prim.app / PrimMac product name on the live signed app
  - Identity lock still holds
---
Internal Mach-O is still Prim. Identity lock is sh.prims.desktop + Prims Desktop.app. Changing the executable name is a codesign/TCC event: rebuild only via ./scripts/build.sh, never a loose CLI Mach-O.
