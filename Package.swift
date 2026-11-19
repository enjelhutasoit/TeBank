// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TeBank",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TeBankCore",
            targets: ["TeBankCore"]
        )
    ],
    targets: [
        .target(
            name: "TeBankCore"
        )
    ],
    swiftLanguageModes: [.v6]
)