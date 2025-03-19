# ComposéUI

[![build](https://github.com/honghaoz/ComposeUI/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/honghaoz/ComposeUI/actions/workflows/build.yml?query=branch%3Amaster)
[![codecov](https://img.shields.io/codecov/c/github/honghaoz/ComposeUI/master?token=9BYHZ8SRBH&flag=ComposeUI&style=flat&label=code%20coverage&color=59B31D)](https://codecov.io/github/honghaoz/ComposeUI/tree/master/ComposeUI%2FSources%2FComposeUI?flags%5B0%5D=ComposeUI&displayType=list)
![swift](https://img.shields.io/badge/swift-5.9-F05138.svg)
![platforms](https://img.shields.io/badge/platforms-macOS%2010.5%20%7C%20iOS%2013.0%20%7C%20tvOS%2013.0%20%7C%20visionOS%201.0-007fea.svg)

**ComposéUI** is a Swift framework for building UI using AppKit and UIKit with declarative syntax.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
  // add the package to your package dependencies
  .package(url: "https://github.com/honghaoz/ComposeUI", from: "0.0.1"),
],
targets: [
  // add products to your target dependencies
  .target(
    name: "MyTarget",
    dependencies: [
      .product(name: "ComposeUI", package: "ComposeUI"),
    ]
  ),
]
```

## Usage

```swift
import ComposeUI

class MyContentView: ComposeView {

  @ComposeContentBuilder
  override var content: ComposeContent {
    Text("Hello, ComposéUI!")
      .transition(.slide(from: .top))
  }
}
```

## License

ComposéUI is available under the MIT license. See the LICENSE file for more info.
