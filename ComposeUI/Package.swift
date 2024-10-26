// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ComposeUI",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .macCatalyst(.v13),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "ComposeUI", targets: ["ComposeUI"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "ComposeUI", dependencies: [], path: "Sources"),
    .testTarget(name: "ComposeUITests", dependencies: ["ComposeUI"], path: "Tests"),
  ]
)
