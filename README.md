# ComposéUI

[![build](https://github.com/honghaoz/ComposeUI/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/honghaoz/ComposeUI/actions/workflows/build.yml?query=branch%3Amaster)
[![codecov](https://img.shields.io/codecov/c/github/honghaoz/ComposeUI/master?token=9BYHZ8SRBH&flag=ComposeUI&style=flat&label=code%20coverage&color=59B31D)](https://codecov.io/github/honghaoz/ComposeUI/tree/master/ComposeUI%2FSources%2FComposeUI?flags%5B0%5D=ComposeUI&displayType=list)
![swift](https://img.shields.io/badge/swift-6.0-F05138.svg)
![platforms](https://img.shields.io/badge/platforms-macOS%2010.15%20%7C%20iOS%2013.0%20%7C%20tvOS%2013.0%20%7C%20visionOS%201.0-007fea.svg)

**ComposéUI** is a Swift framework for building UI using AppKit and UIKit with declarative syntax.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
  // add the package to your package's dependencies
  .package(url: "https://github.com/honghaoz/ComposeUI", from: "0.0.6"),
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

### Quick start

There are three ways to give a `ComposeView` its content. When the state changes, call `refresh()`, or `setNeedsRefresh()` to merge the changes into one refresh at the next layout.

Subclass `ComposeView` and override `content`:

<!-- snippet: ReadmeDemo01QuickStart.swift quick-start -->
```swift
import ComposeUI

class CounterView: ComposeView {

  var count = 0

  @ComposeContentBuilder
  override var content: ComposeContent {
    Label("Count: \(count)")
      .font(.boldSystemFont(ofSize: 24))
  }

  func increment() {
    count += 1
    refresh()
  }
}
```

Or pass a content closure to the initializer. The closure runs on each refresh, so it reads the latest state:

<!-- snippet: ReadmeDemo01QuickStart.swift function contentClosure -->
```swift
var count = 0
let view = ComposeView {
  Label("Count: \(count)")
    .font(.boldSystemFont(ofSize: 24))
}

count += 1
view.refresh()
```

Or set the content of an existing view:

<!-- snippet: ReadmeDemo01QuickStart.swift function setContent -->
```swift
let view = ComposeView()
view.setContent {
  Label("Hello, ComposéUI")
}
```

To nest a `ComposeView` in another view's content, use `ComposeViewNode`.

### Layout

Arrange nodes with `VStack`, `HStack` and `ZStack`, and size them with `Spacer`, `padding` and `frame`.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo02Layout.swift content -->
```swift
HStack(spacing: 12) {
  ZStack {
    ColorNode(.systemBlue)
      .cornerRadius(22)
    Label("DR").textColor(.white)
  }
  .frame(width: 44, height: 44)

  VStack(alignment: .left, spacing: 4) {
    Label("Design Review")
    Label("Today, 3:00 PM")
      .textColor(.systemGray)
  }

  Spacer()

  Label("Join").textColor(.systemBlue)
}
.padding(16)
.background {
  ColorNode(.white).cornerRadius(12)
}
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/803ac806-6b8c-4397-97b3-63c8b7bf674a" width="360">
</td>
</tr>
</table>

### Styling

Round the corners, add a border, or draw a drop shadow or an inner shadow along any path.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo03Styling.swift content -->
```swift
let path = { (size: CGSize) in
  CGPath(
    roundedRect: CGRect(
      origin: .zero,
      size: size
    ),
    cornerWidth: 16,
    cornerHeight: 16,
    transform: nil
  )
}

HStack(spacing: 24) {
  ColorNode(.white)
    .frame(80).cornerRadius(16)
    .border(color: .systemBlue, width: 2)

  ColorNode(.white)
    .frame(80).cornerRadius(16)
    .dropShadow(
      color: .black,
      opacity: 0.2,
      radius: 8,
      offset: .zero,
      path: path
    )

  ColorNode(.white)
    .frame(80).cornerRadius(16)
    .innerShadow(
      color: .black,
      opacity: 0.3,
      radius: 6,
      offset: .zero,
      path: path
    )
}
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/2d114017-7c7f-4dec-b966-abd30a6858a9" width="360">
</td>
</tr>
</table>

### Text

`Label` draws its text into a layer, which keeps long lists fast, and `Text` is a selectable text view that takes attributed strings.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo04Text.swift content -->
```swift
VStack(alignment: .left, spacing: 8) {
  Label("Ready for liftoff 🚀")
    .font(.boldSystemFont(ofSize: 20))

  Label("Labels are drawn, and fast.")
    .textColor(.systemGray)

  Text(
    "Text is a selectable text view.",
    font: .systemFont(ofSize: 15)
  )
  .selectable()
  .fixedSize()
}
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/b77ac5b1-8d5a-475e-ab05-1bc793f21df6" width="360">
</td>
</tr>
</table>

### Animations

Change state, call `refresh()`, and ComposéUI animates the difference.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo05Animations.swift class -->
```swift
var isOn = false

@ComposeContentBuilder
override var content: ComposeContent {
  ColorNode(
    isOn ? .systemOrange : .systemBlue
  )
  .frame(
    width: isOn ? 240 : 80,
    height: 80
  )
  .cornerRadius(isOn ? 40 : 16)
  .animation(.spring())
}

func toggle() {
  isOn.toggle()
  refresh()
}
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/69f51030-9a1e-47a0-ad77-ec51b6a1c034" width="360">
</td>
</tr>
</table>

### Transitions

Give a node a `transition`, and it slides, fades or scales in and out as the content changes.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo06Transitions.swift class -->
```swift
var isShown = true

@ComposeContentBuilder
override var content: ComposeContent {
  HStack(spacing: 24) {
    if isShown {
      ColorNode(.systemBlue).frame(80)
        .transition(.slide(from: .top))

      ColorNode(.systemGreen).frame(80)
        .transition(.opacity())

      ColorNode(.systemOrange).frame(80)
        .transition(.scale())
    }
  }
  .cornerRadius(16)
}
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/a9af0c53-1760-4175-a3dd-8e0bae678ef7" width="360">
</td>
</tr>
</table>

### Interaction

`ButtonNode` builds its content for each state, including hovered and pressed, and calls `onTap` when clicked or tapped.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo07Interaction.swift class -->
```swift
var joined = false

@ComposeContentBuilder
override var content: ComposeContent {
  let joined = self.joined
  ButtonNode(
    content: { state in
      ColorNode(
        joined ? .systemGray : .systemBlue
      )
      .cornerRadius(20)
      .opacity(
        state == .pressed ? 0.6 : (
          state == .hovered ? 0.8 : 1
        )
      )
      .overlay {
        Label(joined ? "Joined" : "Join")
          .textColor(.white)
      }
      .frame(width: 120, height: 40)
    },
    onTap: { [weak self] in
      self?.joined.toggle()
      self?.refresh()
    }
  )
}
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/706fbb11-5f2f-4e14-b5c6-32850831ad26" width="360">
</td>
</tr>
</table>

### Dark mode

A `ThemedColor` resolves to its light or dark value. When the appearance changes, the view refreshes, and the backgrounds with an `animation` animate to their new colors, while text colors switch at once.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo08DarkMode.swift content -->
```swift
let card = ThemedColor(
  light: .white,
  dark: Color(white: 0.15, alpha: 1)
)

let title = ThemedColor(
  light: .black,
  dark: .white
)

HStack {
  VStack(alignment: .left, spacing: 6) {
    Label("Good evening")
      .font(.boldSystemFont(ofSize: 20))
      .textColor(title)

    Label("3 tasks due today")
      .textColor(.systemGray)
  }

  Spacer()

  ColorNode(.systemGreen)
    .frame(12).cornerRadius(6)
}
.padding(20)
.background {
  ColorNode(card).cornerRadius(16)
}
.animation(.easeInEaseOut())
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/00cb4829-9317-4629-91b6-719ac610825f" width="360">
</td>
</tr>
</table>

### Interop

Mix in native views, Core Animation layers and SwiftUI views, here an `NSSwitch`, a `CAShapeLayer` and a SwiftUI `ProgressView`.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo09Interop.swift content -->
```swift
HStack(spacing: 32) {
  ViewNode(make: { _ in
    let toggle = NSSwitch()
    toggle.wantsLayer = true
    toggle.state = .on
    return toggle
  })
  .frame(width: 38, height: 22)

  LayerNode<CAShapeLayer>(
    update: { dot, _ in
      dot.path = CGPath(
        ellipseIn: dot.bounds,
        transform: nil
      )
      dot.fillColor =
        NSColor.systemOrange.cgColor
    }
  )
  .frame(40)

  SwiftUIViewNode {
    ProgressView(value: 0.6)
  }
  .frame(width: 100, height: 20)
}
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/d8805adf-28da-46ff-9c70-4c8862c50590" width="360">
</td>
</tr>
</table>

### Scrolling and performance

A `ComposeView` scrolls when its content overflows and renders only the visible nodes, so a thousand rows scroll smoothly.

<table>
<tr>
<td width="447">

<!-- snippet: ReadmeDemo10Scrolling.swift content -->
```swift
let titles = [
  "Midnight Drive", "Paper Lanterns",
  "Northern Lights", "Slow Tides",
  "City of Glass", "Summer Static",
  "Afterglow",
]

let artists = [
  "Nova Park", "The Tidelines",
  "Ada Rivers", "June & the Echoes",
  "Low Orbit",
]

let colors: [Color] = [
  .systemBlue, .systemTeal, .systemGreen,
  .systemOrange, .systemRed,
]

VStack {
  for i in 1 ... 1000 {
    HStack(spacing: 12) {
      Label("\(i)")
        .textColor(.systemGray)
        .frame(
          width: 32,
          height: .intrinsic
        )

      ColorNode(colors[i % colors.count])
        .frame(40).cornerRadius(8)

      VStack(
        alignment: .left,
        spacing: 2
      ) {
        Label(titles[i % titles.count])
        Label(artists[i % artists.count])
          .textColor(.systemGray)
      }

      Spacer()

      Label("3:\(10 + i * 7 % 50)")
        .textColor(.systemGray)
    }
    .padding(horizontal: 16, vertical: 8)
  }
}
```

</td>
<td width="391">
<img src="https://github.com/user-attachments/assets/bc457d10-ab99-4948-895a-1ebc8b3178f3" width="360">
</td>
</tr>
</table>

## License

ComposéUI is available under the MIT license. See the [LICENSE](https://github.com/honghaoz/ComposeUI/blob/master/LICENSE) file for more info.
