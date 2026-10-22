// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Notepad",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotepadCore"),
        .executableTarget(name: "Notepad", dependencies: ["NotepadCore"]),
        .testTarget(name: "NotepadCoreTests", dependencies: ["NotepadCore"]),
        .testTarget(name: "NotepadAppTests", dependencies: ["Notepad", "NotepadCore"]),
    ],
    swiftLanguageModes: [.v5]
)
