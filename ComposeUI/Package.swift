// swift-tools-version: 6.0

import PackageDescription

// checks that walk a pass's data, and the test switches that hot code reads, are in debug builds, but not in the
// benchmarks' optimized builds, which define DEBUG for the tests' other hooks, so that the benchmarks measure what apps
// run. The tests define it too, so that a test of a switch compiles only where the code that reads the switch does.
let sanityChecks: SwiftSetting = .define("COMPOSEUI_SANITY_CHECKS", .when(configuration: .debug))

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
        sanityChecks,
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
      ],
      swiftSettings: [
        sanityChecks,
      ]
    ),
  ],
  swiftLanguageModes: [.v5]
)
