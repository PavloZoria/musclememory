// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MuscleMemoryXcode",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "musclememory-xcode", targets: ["musclememory-xcode"]),
    ],
    targets: [
        // The editor extension's text commands; the extension (Extension/) compiles these sources too.
        .target(name: "MuscleMemoryEditing"),
        .target(name: "MuscleMemoryXcode", dependencies: ["MuscleMemoryEditing"]),
        .executableTarget(name: "musclememory-xcode", dependencies: ["MuscleMemoryXcode"]),
        .testTarget(name: "MuscleMemoryXcodeTests", dependencies: ["MuscleMemoryXcode"]),
        .testTarget(name: "MuscleMemoryEditingTests", dependencies: ["MuscleMemoryEditing"]),
    ]
)
