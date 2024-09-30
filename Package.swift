// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ComposeUI",
  platforms: [
    .iOS(.v13),
    .tvOS(.v13),
    .visionOS(.v1),
    .macCatalyst(.v13),
  ],
  products: [
    .library(name: "ComposeUI", targets: ["ComposeUI"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "ComposeUI", dependencies: [], path: "ComposeUI/Sources"),
  ]
)
