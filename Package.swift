// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "OmWallpapers",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "OmWallpapers", targets: ["OmWallpapers"])],
    targets: [
        .executableTarget(name: "OmWallpapers"),
        .testTarget(name: "OmWallpapersTests", dependencies: ["OmWallpapers"])
    ],
    swiftLanguageModes: [.v5]
)
