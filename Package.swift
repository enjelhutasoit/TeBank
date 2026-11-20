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
    dependencies: [
        .package(
            url: "https://github.com/enjelhutasoit/VaneKit.git",
            revision: "b767fd63946cd654d72a3a695ff7664765529073"
        )
    ],
    targets: [
        .target(
            name: "TeBankCore"
        ),
        .testTarget(
            name: "TeBankCoreTests",
            dependencies: ["TeBankCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
