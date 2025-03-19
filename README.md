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
  // add the package to your package's dependencies
  .package(url: "https://github.com/honghaoz/ComposeUI", from: "0.0.1"),
],
targets: [
  // add the product to your target's dependencies
  .target(
    name: "MyTarget",
    dependencies: [
      .product(name: "ComposeUI", package: "ComposeUI"),
    ]
  ),
]
```

### Xcode

1. Open your project in Xcode.
2. Select the project in the sidebar.
3. Select the project under the **PROJECT** section.
4. Go to the **Package Dependencies** tab.
5. Click the **+** button enter the package URL: `https://github.com/honghaoz/ComposeUI`.
6. Click **Add Package**.
7. Select the target you want to add `ComposeUI` to under the **Add to Target** section.
8. Click **Add Package**.
9. Add `import ComposeUI` in your file.

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

ComposéUI is available under the MIT license. See the [LICENSE](https://github.com/honghaoz/ComposeUI/blob/master/LICENSE) file for more info.
