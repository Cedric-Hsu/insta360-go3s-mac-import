// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Insta360GO3SImport",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Insta360GO3SImport", targets: ["Insta360GO3SImport"]),
    ],
    targets: [
        .executableTarget(
            name: "Insta360GO3SImport",
            path: "Sources/Insta360GO3SImport"
        ),
    ]
)
