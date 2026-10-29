// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KeyboardLight",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "KeyboardLight", targets: ["KeyboardLight"])
    ],
    targets: [
        .target(
            name: "CoreBrightnessBridge",
            path: "Sources/CoreBrightnessBridge",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .executableTarget(
            name: "KeyboardLight",
            dependencies: ["CoreBrightnessBridge"],
            path: "Sources/KeyboardLight"
        ),
        .testTarget(
            name: "KeyboardLightTests",
            dependencies: ["KeyboardLight"],
            path: "Tests/KeyboardLightTests"
        )
    ]
)
