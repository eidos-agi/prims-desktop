import Darwin
import PrimMacCore

/// Thin PATH client. Does not open chat.db. Talks XPC to the LS-launched app.
let status = PrimsDesktopXPCClient.run(Array(CommandLine.arguments.dropFirst()))
ProcessExit.flushAndExit(status)
