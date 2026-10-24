// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-call-log",
    // macOS only: the stores it reads (CallHistory.storedata, the FaceTime
    // message store, FaceTime.sqlite3 and the block list) are a Mac's own, and
    // nothing third-party reaches the iPhone's copies.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CallLog", targets: ["CallLog"]),
    ],
    targets: [
        // Synchronous and local: no transport, nothing to await, so the
        // nonisolated-nonsending feature is left off.
        .target(name: "CallLog"),
        .testTarget(name: "CallLogTests", dependencies: ["CallLog"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
