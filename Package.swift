// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "tebank",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TeBankCore",
            targets: ["TeBankCore"]
        ),
        .library(name: "TeBankUI", targets: ["TeBankUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/enjelhutasoit/SwiftTransferKit.git", revision: "006b24895dc1201bdbdba1e2f773d0f5ced873ea"),
        .package(
            url: "https://github.com/enjelhutasoit/VaneKit.git",
            revision: "b767fd63946cd654d72a3a695ff7664765529073"
        )
    ],
    targets: [
        .target(
            name: "TeBankCore",
            dependencies: [
                .product(name: "TransferDomain", package: "SwiftTransferKit"),
                .product(name: "TransferCore", package: "SwiftTransferKit"),
                .product(name: "TransferSimulation", package: "SwiftTransferKit"),
                .product(name: "TransferPersistence", package: "SwiftTransferKit")
            ]
        ),
        .target(
            name: "TeBankUI",
            dependencies: ["TeBankCore", .product(name: "VaneKit", package: "VaneKit")]
        ),
        .testTarget(
            name: "TeBankCoreTests",
            dependencies: ["TeBankCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
