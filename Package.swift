// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Notepad",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotepadCore"),
        .testTarget(name: "NotepadCoreTests", dependencies: ["NotepadCore"]),
    ],
    swiftLanguageModes: [.v5]
)
