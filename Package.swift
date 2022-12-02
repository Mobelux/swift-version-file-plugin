// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VersionFilePlugin",
    products: [
        .plugin(name: "VersionFile", targets: ["VersionFile"])
    ],
    dependencies: [
    ],
    targets: [
        .plugin(
            name: "VersionFile",
            capability: .command(
                intent: .custom(
                    verb: "version-file",
                    description: "Generates and increments `Version.swift`"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "This command writes `Version.swift` to the source root.")
                ]),
            dependencies: [
                .target(name: "semver")
            ]),
        .binaryTarget(
            name: "semver",
            path: "Artifacts/semver.artifactbundle"),
    ]
)
