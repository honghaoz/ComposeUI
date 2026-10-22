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
  dependencies: [],
  targets: [
    .target(
      name: "ComposeUI",
      dependencies: [],
      path: "ComposeUI/Sources",
      swiftSettings: [
        // checks that walk a pass's data run in debug builds, but not in the benchmarks' optimized builds, which define
        // DEBUG for the tests' hooks, so that the benchmarks measure what apps run
        .define("COMPOSEUI_SANITY_CHECKS", .when(configuration: .debug)),
      ]
    ),
  ],
  swiftLanguageModes: [.v5]
)
