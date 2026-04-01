// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PromptWise",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PromptWise",
            path: "Sources/PromptWise",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
