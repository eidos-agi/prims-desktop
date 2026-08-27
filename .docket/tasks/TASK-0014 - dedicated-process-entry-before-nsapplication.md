---
id: TASK-0014
title: Dedicated process entry before NSApplication
status: To Do
created: '2026-08-27'
priority: high
milestone: MS-0002
tags:
  - ship
  - tcc
  - cli
acceptance-criteria:
  - '@main is a real static main (PrimDesktopMain or main.swift), not PrimApp.init() after SwiftUI is constructing'
  - Strip @main from PrimApp
  - 'CLI verbs call DesktopCLI.run and _exit before NSApplication/SwiftUI: doctor, status, receive, connectors, open, asmp, config, help, --json, -h, --help'
  - GUI path (double-click / open -a, no CLI argv) still calls PrimApp.main() and is unchanged
  - Contents/MacOS/Prim doctor does not hang, does not setActivationPolicy(.regular), does not activate windows
definition-of-done:
  - 'HostTest or prove: CLI argv exits with no window'
  - open -a still opens the glass
---
Company-grade. PrimApp currently @main with DeskAppDelegate.applicationDidFinishLaunching activating the GUI. That is why Prim doctor hung. An init() peek is too late. Cover every DesktopCLI verb, not a short allow-list.
