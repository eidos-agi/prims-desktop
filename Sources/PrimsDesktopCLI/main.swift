import Darwin
import PrimMacCore

/// Thin PATH client, or launchd broker when argv is --xpc-broker.
/// Never opens chat.db.
if CommandLine.arguments.contains(ProductIdentity.xpcBrokerFlag) {
    PrimsDesktopXPCBroker.run()
}
let args = Array(CommandLine.arguments.dropFirst())
let status = PrimsDesktopXPCClient.run(args)
ProcessExit.flushAndExit(status)
