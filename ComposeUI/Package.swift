// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ComposeUI",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "ComposeUI", targets: ["ComposeUI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/honghaoz/ChouTi", branch: "master"),
  ],
  targets: [
    .target(
      name: "ComposeUI",
      dependencies: [],
      path: "Sources",
      exclude: [
        "ComposeUI/_Deprecated",
      ],
      swiftSettings: [
        // checks that walk a pass's data run in debug builds, but not in the benchmarks' optimized builds, which define
        // DEBUG for the tests' hooks, so that the benchmarks measure what apps run
        .define("COMPOSEUI_SANITY_CHECKS", .when(configuration: .debug)),
      ]
    ),
    .testTarget(
      name: "ComposeUITests",
      dependencies: [
        "ComposeUI",
        .product(name: "ChouTi", package: "ChouTi"),
        .product(name: "ChouTiTest", package: "ChouTi"),
      ],
      path: "Tests",
      exclude: [
        "ComposeUITests/_Deprecated",
      ]
    ),
  ],
  swiftLanguageModes: [.v5]
)
