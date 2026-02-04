// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WallpaperApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WallpaperApp", targets: ["WallpaperApp"])
    ],
    targets: [
        .executableTarget(
            name: "WallpaperApp",
            resources: []
        )
    ]
)
