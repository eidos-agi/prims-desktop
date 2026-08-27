// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PrimMac",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PrimMacCore", targets: ["PrimMacCore"]),
        .executable(name: "PrimMac", targets: ["PrimMac"]),
        .executable(name: "prims-desktop", targets: ["PrimsDesktopCLI"]),
        .executable(name: "imessage-chatdb-receive", targets: ["IMessageChatDBReceive"]),
    ],
    dependencies: [
        .package(path: "../prim-sim"),
    ],
    targets: [
        .target(
            name: "PrimMacCore",
            dependencies: [
                .product(name: "PrimSimCore", package: "prim-sim"),
            ],
            path: "Sources/PrimMacCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "PrimMac",
            dependencies: [
                "PrimMacCore",
                .product(name: "PrimSimCore", package: "prim-sim"),
            ],
            path: "Sources/PrimMac",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("WebKit"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "PrimsDesktopCLI",
            dependencies: [
                "PrimMacCore",
                .product(name: "PrimSimCore", package: "prim-sim"),
            ],
            path: "Sources/PrimsDesktopCLI",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "IMessageChatDBReceive",
            dependencies: [
                "PrimMacCore",
            ],
            path: "Sources/IMessageChatDBReceive",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "PrimMacTests",
            dependencies: [
                "PrimMacCore",
                .product(name: "PrimSimCore", package: "prim-sim"),
            ],
            path: "Tests/PrimMacTests"
        ),
    ]
)
