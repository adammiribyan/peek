// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Peek",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/PostHog/posthog-ios.git", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Peek",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "PostHog", package: "posthog-ios"),
            ],
            path: "Peek",
            exclude: ["Peek.entitlements", "Resources/AppIcon.icns", "Secrets.swift.example"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
