// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BHyve",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: [
        .library(name: "BHyve", targets: ["BHyve"]),
    ],
    targets: [
        .target(name: "BHyve"),
        .testTarget(
            name: "BHyveTests",
            dependencies: ["BHyve"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
