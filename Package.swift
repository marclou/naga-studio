// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NagaStudio",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "NagaStudio",
            path: "sources",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
