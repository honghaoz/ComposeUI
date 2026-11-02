//
//  LabelDrawingLabWindow.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/16/26.
//  Copyright © 2024 Honghao Zhang.
//
//  MIT License
//
//  Copyright (c) 2024 Honghao Zhang (github.com/honghaoz)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import AppKit
import Metal

import ComposeUI

/// A resizable window for the label drawing lab.
final class LabelDrawingLabWindow: NSWindowController {

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: Constants.initialSize.width, height: Constants.initialSize.height),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Label Drawing Lab"
    window.minSize = Constants.minSize

    self.init(window: window)

    let lab = LabelDrawingLab(frame: window.contentLayoutRect)
    lab.autoresizingMask = [.width, .height]
    window.contentView = lab
    window.center()
  }

  // MARK: - Constants

  private enum Constants {
    static let initialSize = CGSize(width: 1180, height: 900)
    static let minSize = CGSize(width: 760, height: 520)
  }
}

/// A lab that compares how AppKit draws a label's text with how a layer draws it, pixel for pixel.
///
/// Each row draws a text in offscreen windows and renders what the windows show through Core Animation, as the label
/// drawing parity tests do. The columns show the text drawn:
/// - through AppKit, which a style that the label doesn't know makes the label do,
/// - by the label as it ships, which draws in its layer only for a text that the tests verify,
/// - by a layer that draws as the label's drawing layer does, for any text, including the styles that keep AppKit's
///   drawing,
/// - and through AppKit, faded, with the pixels where the layer differs in red.
///
/// The first row draws the text in the field, with the font, the styles, the width and the lines of the controls.
private final class LabelDrawingLab: NSView, NSTextFieldDelegate {

  private let textField = NSTextField(string: Constants.initialText)
  private let fontSizeSlider = NSSlider(value: Constants.initialFontSize, minValue: 8, maxValue: 48, target: nil, action: nil)
  private let fontSizeLabel = NSTextField(labelWithString: "")
  private let widthSlider = NSSlider(value: Constants.initialWidth, minValue: 40, maxValue: 400, target: nil, action: nil)
  private let widthLabel = NSTextField(labelWithString: "")
  private let linesPopUp = NSPopUpButton()
  private let colorPopUp = NSPopUpButton()
  private let styleCheckboxes = Style.allCases.map { NSButton(checkboxWithTitle: $0.title, target: nil, action: nil) }
  private let appearancePopUp = NSPopUpButton()
  private let zoomPopUp = NSPopUpButton()
  private let noteLabel = NSTextField(wrappingLabelWithString: "")
  private let controls = NSStackView()

  private let renderer = LabelRenderer()
  private var customRow: Row?
  private var sampleRows: [Row] = []

  private lazy var table = ComposeView { [weak self] in
    self?.tableContent ?? Empty()
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    setUpControls()
    addSubview(controls)
    addSubview(table)
    sampleRows = Samples.all.map(compare)
    customRow = compare(customSample)
    table.refresh(animated: false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override func layout() {
    super.layout()

    let controlsHeight = controls.fittingSize.height
    controls.frame = CGRect(
      x: Constants.padding,
      y: bounds.height - Constants.padding - controlsHeight,
      width: bounds.width - Constants.padding * 2,
      height: controlsHeight
    )
    table.frame = CGRect(x: 0, y: 0, width: bounds.width, height: controls.frame.minY - Constants.padding)
  }

  // MARK: - Controls

  private func setUpControls() {
    textField.placeholderString = "Type a text to compare"
    textField.delegate = self

    linesPopUp.addItems(withTitles: Constants.lines.map(\.title))
    colorPopUp.addItems(withTitles: Constants.colors.map(\.title))
    appearancePopUp.addItems(withTitles: Constants.appearances.map(\.title))
    zoomPopUp.addItems(withTitles: Constants.zooms.map { "Zoom \(Self.describe($0))x" })

    let changingControls: [NSControl] = [fontSizeSlider, widthSlider, linesPopUp, colorPopUp, appearancePopUp, zoomPopUp] + styleCheckboxes
    for control in changingControls {
      control.target = self
      control.action = #selector(controlChanged(_:))
    }
    for slider in [fontSizeSlider, widthSlider] {
      slider.widthAnchor.constraint(equalToConstant: Constants.sliderWidth).isActive = true
    }
    for label in [fontSizeLabel, widthLabel] {
      label.widthAnchor.constraint(equalToConstant: Constants.valueLabelWidth).isActive = true
    }
    // the windows draw at the scale that AppKit gives them, the main screen's, since a window that claims another
    // scale doesn't draw as a screen of that scale does
    noteLabel.textColor = .secondaryLabelColor
    noteLabel.stringValue = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString), drawn at the scale of the main screen. A label draws in its layer only for the styles, the sizes in whole pixels and the systems that the label drawing parity tests verify, and through AppKit otherwise. The lab's layer draws any text as the label's drawing layer does, to show why a style keeps AppKit's drawing."

    let sizeRow = NSStackView(
      views: [
        NSTextField(labelWithString: "Size"),
        fontSizeSlider,
        fontSizeLabel,
        NSTextField(labelWithString: "Width"),
        widthSlider,
        widthLabel,
        linesPopUp,
        colorPopUp,
      ]
    )
    let styleRow = NSStackView(views: styleCheckboxes + [appearancePopUp, zoomPopUp])
    controls.orientation = .vertical
    controls.alignment = .leading
    controls.spacing = Constants.controlSpacing
    for view in [textField, sizeRow, styleRow, noteLabel] {
      controls.addArrangedSubview(view)
    }
    for view in [textField, noteLabel] {
      view.widthAnchor.constraint(equalTo: controls.widthAnchor).isActive = true
    }
    updateValueLabels()
  }

  @objc private func controlChanged(_ sender: NSControl) {
    updateValueLabels()
    // the samples' drawings depend only on the appearance
    if sender === appearancePopUp {
      sampleRows = Samples.all.map(compare)
    }
    customRow = compare(customSample)
    table.refresh(animated: false)
  }

  func controlTextDidChange(_ notification: Notification) {
    customRow = compare(customSample)
    table.refresh(animated: false)
  }

  private func updateValueLabels() {
    fontSizeLabel.stringValue = "\(Self.describe(fontSize)) pt"
    widthLabel.stringValue = "\(Self.describe(width)) pt"
  }

  private var fontSize: CGFloat {
    (fontSizeSlider.doubleValue * 2).rounded() / 2
  }

  /// The label's width, in whole points, since a compose view puts a label on whole pixels anyway.
  private var width: CGFloat {
    widthSlider.doubleValue.rounded()
  }

  /// The appearance of the windows that draw the texts, with the background to show their drawings on.
  private var captureAppearance: (title: String, name: NSAppearance.Name, background: NSColor) {
    Constants.appearances[appearancePopUp.indexOfSelectedItem]
  }

  private var zoom: CGFloat {
    Constants.zooms[zoomPopUp.indexOfSelectedItem]
  }

  private var customSample: Sample {
    let styles = Set(zip(Style.allCases, styleCheckboxes).filter { $0.1.state == .on }.map(\.0))
    var font = NSFont.systemFont(ofSize: fontSize, weight: styles.contains(.bold) ? .bold : .regular)
    if styles.contains(.italic) {
      font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
    var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Constants.colors[colorPopUp.indexOfSelectedItem].color]
    if styles.contains(.underline) {
      attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
    }
    if styles.contains(.strikethrough) {
      attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    }
    if styles.contains(.shadow) {
      attributes[.shadow] = Samples.shadow
    }
    if styles.contains(.background) {
      attributes[.backgroundColor] = NSColor.systemYellow
    }
    let lines = Constants.lines[linesPopUp.indexOfSelectedItem].count
    let text = NSAttributedString(string: textField.stringValue, attributes: attributes)
    return Sample(name: "Your text", text: text, width: width, lines: lines, lineBreakMode: lines == 1 ? .byTruncatingTail : .byWordWrapping)
  }

  private func compare(_ sample: Sample) -> Row {
    Row(name: sample.name, comparison: renderer.compare(sample, appearance: NSAppearance(named: captureAppearance.name)))
  }

  // MARK: - Table

  @ComposeContentBuilder
  private var tableContent: ComposeContent {
    let rows = (customRow.map { [$0] } ?? []) + sampleRows
    let zoom = zoom
    let columnWidth = rows.reduce(Constants.minimumColumnWidth) { max($0, ($1.comparison?.size.width ?? 0) * zoom) }
    let scale = rows.lazy.compactMap(\.comparison).first?.scale

    VStack(alignment: .left, spacing: Constants.rowSpacing) {
      HStack(alignment: .top, spacing: Constants.columnSpacing) {
        Self.text(scale.map { "Drawn at \(Self.describe($0))x" } ?? "", color: .secondaryLabelColor)
          .frame(width: Constants.nameWidth, height: Constants.headerHeight, alignment: .topLeft)
        for title in ["AppKit draws the view", "The label, as it ships", "A layer draws the text", "Pixels that differ, in red"] {
          Self.text(title, weight: .semibold)
            .frame(width: columnWidth, height: Constants.headerHeight, alignment: .topLeft)
        }
      }
      .frame(width: .flexible, height: Constants.headerHeight, alignment: .left)

      for row in rows {
        rowContent(row, columnWidth: columnWidth, zoom: zoom)
      }
    }
    .padding(horizontal: Constants.padding, vertical: Constants.padding)
  }

  private func rowContent(_ row: Row, columnWidth: CGFloat, zoom: CGFloat) -> ComposeNode {
    guard let comparison = row.comparison else {
      return Self.text("\(row.name): rendering through Core Animation requires a Metal device", color: .systemRed)
        .frame(width: .flexible, height: Constants.headerHeight, alignment: .left)
    }
    let imageSize = CGSize(width: comparison.size.width * zoom, height: comparison.size.height * zoom)
    let height = imageSize.height + Constants.captionSpacing + Constants.captionHeight
    let background = captureAppearance.background

    let labelCaption: (String, NSColor)
    switch (comparison.labelDrawsInLayer, comparison.labelDifferingPixelCount) {
    case (true, 0):
      labelCaption = ("draws in its layer", .secondaryLabelColor)
    case (false, 0):
      labelCaption = ("AppKit draws", .secondaryLabelColor)
    case (_, let count):
      labelCaption = ("\(count) pixels differ from AppKit", .systemRed)
    }

    let layerCaption: (String, NSColor)
    switch comparison.layerCopyDifferingPixelCount {
    case .none:
      layerCaption = ("", .secondaryLabelColor)
    case .some(0):
      layerCaption = ("same pixels as the label's layer", .secondaryLabelColor)
    case .some(let count):
      layerCaption = ("\(count) pixels differ from the label's layer, so the lab's layer needs an update", .systemRed)
    }

    let differenceCaption = comparison.layerDifferingPixelCount == 0
      ? ("same pixels", NSColor.systemGreen)
      : ("\(comparison.layerDifferingPixelCount) pixels differ", NSColor.systemRed)

    return HStack(alignment: .top, spacing: Constants.columnSpacing) {
      Self.text(row.name, weight: .semibold)
        .frame(width: Constants.nameWidth, height: height, alignment: .topLeft)
      Self.cell(comparison.appKitImage, size: imageSize, background: background, caption: ("", .secondaryLabelColor))
        .frame(width: columnWidth, height: height, alignment: .topLeft)
      Self.cell(comparison.labelImage, size: imageSize, background: background, caption: labelCaption)
        .frame(width: columnWidth, height: height, alignment: .topLeft)
      Self.cell(comparison.layerImage, size: imageSize, background: background, caption: layerCaption)
        .frame(width: columnWidth, height: height, alignment: .topLeft)
      Self.cell(comparison.differenceImage, size: imageSize, background: background, caption: differenceCaption)
        .frame(width: columnWidth, height: height, alignment: .topLeft)
    }
    .frame(width: .flexible, height: height, alignment: .left)
  }

  private static func cell(_ image: CGImage?, size: CGSize, background: NSColor, caption: (String, NSColor)) -> ComposeNode {
    VStack(alignment: .left, spacing: Constants.captionSpacing) {
      // the image shows its pixels as squares when zoomed, instead of smoothing them
      LayerNode<CALayer>(update: { layer, _ in
        layer.contents = image
        layer.contentsGravity = .resize
        layer.magnificationFilter = .nearest
        layer.backgroundColor = background.cgColor
      })
      .frame(width: size.width, height: size.height)

      text(caption.0, color: caption.1)
        .frame(width: .flexible, height: Constants.captionHeight, alignment: .topLeft)
    }
  }

  private static func text(_ string: String, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> LabelNode {
    Label(string)
      .font(.systemFont(ofSize: Constants.tableFontSize, weight: weight))
      .textColor(color)
      .numberOfLines(0)
      .lineBreakMode(.byWordWrapping)
      .textAlignment(.left)
      .selectable(false)
  }

  private static func describe(_ value: CGFloat) -> String {
    value == value.rounded() ? "\(Int(value))" : "\(value)"
  }

  // MARK: - Constants

  private enum Constants {

    static let initialText = "The quick brown fox jumps over the lazy dog"
    static let initialFontSize: Double = 15
    static let initialWidth: Double = 240
    static let padding: CGFloat = 12
    static let controlSpacing: CGFloat = 8
    static let sliderWidth: CGFloat = 140
    static let valueLabelWidth: CGFloat = 64
    static let nameWidth: CGFloat = 130
    static let minimumColumnWidth: CGFloat = 180
    static let columnSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 12
    static let headerHeight: CGFloat = 18
    static let captionSpacing: CGFloat = 4
    static let captionHeight: CGFloat = 28
    static let tableFontSize: CGFloat = 11
    static let lines: [(title: String, count: Int)] = [("1 line", 1), ("2 lines", 2), ("Unlimited lines", 0)]
    static let colors: [(title: String, color: NSColor)] = [
      ("Label color", .labelColor),
      ("Secondary label color", .secondaryLabelColor),
      ("Black", .black),
      ("System blue", .systemBlue),
      ("Display P3 red", NSColor(displayP3Red: 1, green: 0.1, blue: 0.1, alpha: 1)),
    ]
    static let appearances: [(title: String, name: NSAppearance.Name, background: NSColor)] = [
      ("Light", .aqua, .white),
      ("Dark", .darkAqua, NSColor(white: 0.12, alpha: 1)),
    ]
    static let zooms: [CGFloat] = [1, 2, 4]
  }
}

// MARK: - Samples

/// A style that the lab's controls add to the text in the field.
private enum Style: CaseIterable {

  case bold
  case italic
  case underline
  case strikethrough
  case shadow
  case background

  var title: String {
    switch self {
    case .bold:
      return "Bold"
    case .italic:
      return "Italic"
    case .underline:
      return "Underline"
    case .strikethrough:
      return "Strikethrough"
    case .shadow:
      return "Shadow"
    case .background:
      return "Background"
    }
  }
}

/// A text to draw in a label of a size, with the label's settings.
private struct Sample {

  let name: String
  let text: NSAttributedString
  let size: CGSize
  let lines: Int
  let lineBreakMode: NSLineBreakMode

  /// Creates a sample whose label is as tall as the text's lines.
  init(name: String, text: NSAttributedString, width: CGFloat, lines: Int = 1, lineBreakMode: NSLineBreakMode = .byTruncatingTail) {
    self.name = name
    self.text = text
    self.lines = lines
    self.lineBreakMode = lineBreakMode
    size = CGSize(width: width, height: Self.height(of: text, width: width, lines: lines, lineBreakMode: lineBreakMode))
  }

  private static func height(of text: NSAttributedString, width: CGFloat, lines: Int, lineBreakMode: NSLineBreakMode) -> CGFloat {
    let textStorage = NSTextStorage(attributedString: text)
    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
    textContainer.lineFragmentPadding = 0
    textContainer.maximumNumberOfLines = lines
    textContainer.lineBreakMode = lineBreakMode
    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)
    layoutManager.ensureLayout(for: textContainer)
    return max(layoutManager.usedRect(for: textContainer).height.rounded(.up), 1)
  }
}

/// The texts that the lab compares below the text in the field.
private enum Samples {

  static let shadow: NSShadow = {
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 1, height: -1)
    shadow.shadowBlurRadius = 2
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
    return shadow
  }()

  static let all: [Sample] = {
    let width: CGFloat = 220
    let wrap = NSLineBreakMode.byWordWrapping
    let paragraph = "A paragraph that wraps across several lines in a narrow label."
    let link = NSMutableAttributedString(attributedString: text("Visit the link here"))
    link.addAttribute(.link, value: "https://example.com", range: NSRange(location: 10, length: 4))
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    centered.paragraphSpacing = 6
    let attachment = NSTextAttachment()
    attachment.image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
      NSColor.systemBlue.setFill()
      rect.fill()
      return true
    }
    let withImage = NSMutableAttributedString(attributedString: text("Image "))
    withImage.append(NSAttributedString(attachment: attachment))
    withImage.append(text(" after"))

    return [
      Sample(name: "Title", text: text("Row 12 title", [.font: NSFont.systemFont(ofSize: 15, weight: .semibold)]), width: width),
      Sample(name: "Secondary color", text: text("Secondary label color", [.foregroundColor: NSColor.secondaryLabelColor]), width: width),
      Sample(name: "Small", text: text("Tiny system text at nine points", [.font: NSFont.systemFont(ofSize: 9)]), width: width),
      Sample(name: "Wrapped", text: text(paragraph), width: width, lines: 0, lineBreakMode: wrap),
      Sample(name: "Truncated", text: text("A long line that is truncated at the end of the label"), width: width),
      Sample(name: "Right to left", text: text("مرحبا بالعالم، هذا نص عربي"), width: width, lines: 0, lineBreakMode: wrap),
      Sample(name: "Chinese", text: text("中文文本的标签显示"), width: width),
      Sample(name: "Underline", text: text("Underlined text", [.underlineStyle: NSUnderlineStyle.single.rawValue]), width: width),
      Sample(name: "Shadow", text: text("Shadowed text", [.font: NSFont.boldSystemFont(ofSize: 17), .foregroundColor: NSColor.systemRed, .shadow: shadow]), width: width),
      Sample(name: "Link", text: link, width: width),
      Sample(name: "Paragraph style", text: text("Centered with spacing\nSecond paragraph", [.paragraphStyle: centered]), width: width, lines: 0, lineBreakMode: wrap),
      Sample(name: "Kern", text: text("Kerned text", [.kern: 2]), width: width),
      Sample(name: "Strikethrough", text: text("Struck through text", [.strikethroughStyle: NSUnderlineStyle.single.rawValue]), width: width),
      Sample(name: "Thick underline", text: text("Thick underline", [.underlineStyle: NSUnderlineStyle.thick.rawValue]), width: width),
      Sample(name: "Background color", text: text("Background color", [.backgroundColor: NSColor.systemYellow]), width: width),
      Sample(name: "Outline stroke", text: text("Outlined text", [.font: NSFont.boldSystemFont(ofSize: 20), .strokeWidth: 3, .strokeColor: NSColor.systemBlue]), width: width),
      Sample(name: "Image attachment", text: withImage, width: width),
      Sample(name: "Emoji", text: text("Emoji \u{1F600}\u{1F389}"), width: width),
    ]
  }()

  private static func text(_ string: String, _ attributes: [NSAttributedString.Key: Any] = [:]) -> NSAttributedString {
    var allAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.labelColor]
    allAttributes.merge(attributes) { $1 }
    return NSAttributedString(string: string, attributes: allAttributes)
  }
}

// MARK: - Rendering

/// A sample's row in the table.
private struct Row {

  let name: String

  /// The drawings of the sample, or `nil` without a Metal device.
  let comparison: Comparison?
}

/// The drawings of a text, in AppKit, in the label and in the lab's layer, with the pixels where they differ.
private struct Comparison {

  /// The scale that the windows drew at.
  let scale: CGFloat

  /// The size of each drawing, in points.
  let size: CGSize

  let appKitImage: CGImage?
  let labelImage: CGImage?
  let layerImage: CGImage?

  /// The AppKit drawing, faded, with the pixels where the layer differs in red.
  let differenceImage: CGImage?

  /// Whether the label draws the text in its layer, instead of AppKit drawing it.
  let labelDrawsInLayer: Bool

  /// The number of pixels where the label differs from AppKit, which is zero either way the label draws.
  let labelDifferingPixelCount: Int

  /// The number of pixels where the lab's layer differs from AppKit.
  let layerDifferingPixelCount: Int

  /// The number of pixels where the lab's layer differs from the label's drawing layer, for a label that draws in its
  /// layer, which is zero while the lab's layer draws as the label's does.
  let layerCopyDifferingPixelCount: Int?
}

/// Draws texts in labels in offscreen windows, and renders what the windows show through Core Animation, one pixel of a
/// window's backing store to one pixel.
private final class LabelRenderer {

  private let commandQueue = MTLCreateSystemDefaultDevice()?.makeCommandQueue()

  /// Returns the drawings of a sample, or `nil` without a Metal device, which the renderer needs.
  func compare(_ sample: Sample, appearance: NSAppearance?) -> Comparison? {
    guard let commandQueue else {
      return nil
    }

    // a style that the label doesn't know keeps AppKit's drawing, and draws nothing
    let appKitText = NSMutableAttributedString(attributedString: sample.text)
    appKitText.addAttribute(Constants.appKitDrawingKey, value: true, range: NSRange(location: 0, length: appKitText.length))
    let appKitWindow = CaptureWindow(appearance: appearance, size: sample.size)
    let appKitLabel = appKitWindow.showLabel(appKitText, sample)

    let labelWindow = CaptureWindow(appearance: appearance, size: sample.size)
    let label = labelWindow.showLabel(sample.text, sample)

    // the layer draws where the label is, in its size, which the compose view puts on whole pixels
    let layerWindow = CaptureWindow(appearance: appearance, size: sample.size)
    layerWindow.showLayerCopy(drawing: appKitLabel, frame: appKitLabel.map { $0.convert($0.bounds, to: appKitWindow.canvas) } ?? .zero)

    // the windows commit before they draw, since in an app a window that draws before its first commit draws some
    // colors slightly apart from one that draws after it, whichever way it draws, which would show as a difference
    // between the windows
    CATransaction.flush()

    guard let appKitPixels = render(appKitWindow, commandQueue),
          let labelPixels = render(labelWindow, commandQueue),
          let layerPixels = render(layerWindow, commandQueue)
    else {
      return nil
    }

    let scale = appKitWindow.backingScaleFactor
    let labelDrawsInLayer = label?.wantsUpdateLayer ?? false
    return Comparison(
      scale: scale,
      size: CGSize(width: CGFloat(appKitPixels.width) / scale, height: CGFloat(appKitPixels.height) / scale),
      appKitImage: appKitPixels.image,
      labelImage: labelPixels.image,
      layerImage: layerPixels.image,
      differenceImage: appKitPixels.differenceImage(from: layerPixels),
      labelDrawsInLayer: labelDrawsInLayer,
      labelDifferingPixelCount: labelPixels.differingPixelCount(from: appKitPixels),
      layerDifferingPixelCount: layerPixels.differingPixelCount(from: appKitPixels),
      layerCopyDifferingPixelCount: labelDrawsInLayer ? layerPixels.differingPixelCount(from: labelPixels) : nil
    )
  }

  private func render(_ window: CaptureWindow, _ commandQueue: MTLCommandQueue) -> Pixels? {
    window.displayIfNeeded()

    let canvas = window.canvas
    let scale = window.backingScaleFactor
    let width = Int((canvas.bounds.width * scale).rounded(.up))
    let height = Int((canvas.bounds.height * scale).rounded(.up))
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    guard width > 0, height > 0, let layer = canvas.layer, let texture = commandQueue.device.makeTexture(descriptor: descriptor) else {
      return nil
    }

    // the renderer maps the layer's points to the texture's pixels one to one, so the canvas scales its sublayers to
    // show their contents one pixel to one pixel
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1)
    CATransaction.commit()

    let renderer = CARenderer(mtlTexture: texture, options: [kCARendererMetalCommandQueue: commandQueue])
    renderer.layer = layer
    renderer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
    // the renderer takes the layer tree when the transaction commits
    CATransaction.flush()
    renderer.beginFrame(atTime: CACurrentMediaTime(), timeStamp: nil)
    renderer.addUpdate(renderer.bounds)
    renderer.render()
    renderer.endFrame()

    // a command buffer committed after the renderer's work on the same queue completes after it
    let fence = commandQueue.makeCommandBuffer()
    fence?.commit()
    fence?.waitUntilCompleted()
    renderer.layer = nil

    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { buffer in
      if let baseAddress = buffer.baseAddress {
        texture.getBytes(baseAddress, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
      }
    }
    return Pixels(width: width, height: height, bytes: bytes)
  }

  // MARK: - Constants

  private enum Constants {

    /// A style that a label doesn't know, which keeps AppKit's drawing and draws nothing itself.
    static let appKitDrawingKey = NSAttributedString.Key("ComposeUIPlayground.appKitDrawing")
  }
}

/// An offscreen window with a canvas to render.
private final class CaptureWindow: NSWindow {

  /// The view that the renderer renders.
  let canvas: NSView

  init(appearance: NSAppearance?, size: CGSize) {
    canvas = NSView(frame: CGRect(origin: .zero, size: size))

    super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: [.closable, .miniaturizable, .resizable], backing: .buffered, defer: false)

    self.appearance = appearance
    contentView?.wantsLayer = true
    canvas.wantsLayer = true
    contentView?.addSubview(canvas)
  }

  /// Shows a text in a label through a compose view, as an app does, and returns the label.
  func showLabel(_ text: NSAttributedString, _ sample: Sample) -> TextLabelView? {
    var labelView: TextLabelView?
    let composeView = ComposeView {
      // a text that the user can't select shows in a label, instead of a text view
      TextNode(text)
        .numberOfLines(sample.lines)
        .lineBreakMode(sample.lineBreakMode)
        .selectable(false)
        .onInsert { renderable, _ in
          labelView = renderable.view as? TextLabelView
        }
    }
    composeView.frame = canvas.bounds
    canvas.addSubview(composeView)
    composeView.refresh(animated: false)
    return labelView
  }

  /// Shows a layer that draws a label's text as the label's drawing layer does, in a flipped view of a frame, as the
  /// label is.
  func showLayerCopy(drawing labelView: TextLabelView?, frame: CGRect) {
    let host = FlippedView(frame: frame)
    host.wantsLayer = true
    canvas.addSubview(host)

    let layer = LayerDrawingCopy()
    layer.labelView = labelView
    layer.frame = host.bounds
    layer.contentsScale = backingScaleFactor
    // as in the label's drawing layer, the layer's contents aren't flipped in the flipped view, which offsets shadows
    // as AppKit does, and its drawing flips the context instead
    layer.isGeometryFlipped = true
    host.layer?.addSublayer(layer)
    layer.setNeedsDisplay()
  }
}

private final class FlippedView: NSView {

  override var isFlipped: Bool {
    true
  }
}

/// A layer that draws a label's text as the label's drawing layer does, which a label uses only for the texts that the
/// parity tests verify, so the lab can show how a layer draws any text.
private final class LayerDrawingCopy: CALayer {

  weak var labelView: TextLabelView?

  override func action(forKey event: String) -> CAAction? {
    nil
  }

  override func draw(in ctx: CGContext) {
    guard #available(macOS 11.0, *), let labelView else {
      return
    }

    ctx.translateBy(x: 0, y: bounds.height)
    ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    labelView.effectiveAppearance.performAsCurrentDrawingAppearance {
      labelView.draw(labelView.bounds)
    }
    NSGraphicsContext.restoreGraphicsState()
  }
}

/// The pixels that a window shows, in BGRA, premultiplied, from the bottom row up.
private struct Pixels {

  let width: Int
  let height: Int
  let bytes: [UInt8]

  /// The pixels as an image, from the top row down.
  var image: CGImage? {
    Self.image(width: width, height: height, bytes: bytes)
  }

  /// Returns the number of pixels that differ from other pixels of the same size, or `Int.max` for another size.
  func differingPixelCount(from other: Pixels) -> Int {
    guard width == other.width, height == other.height else {
      return Int.max
    }
    return stride(from: 0, to: bytes.count, by: 4).filter { index in
      (0 ..< 4).contains { bytes[index + $0] != other.bytes[index + $0] }
    }.count
  }

  /// Returns an image of these pixels, faded, with the pixels that differ from other pixels in red.
  func differenceImage(from other: Pixels) -> CGImage? {
    guard width == other.width, height == other.height else {
      return nil
    }
    var difference = bytes
    for index in stride(from: 0, to: bytes.count, by: 4) {
      if (0 ..< 4).contains(where: { bytes[index + $0] != other.bytes[index + $0] }) {
        difference.replaceSubrange(index ..< index + 4, with: [0, 0, 255, 255])
      } else {
        for channel in index ..< index + 4 {
          difference[channel] = bytes[channel] / 4
        }
      }
    }
    return Self.image(width: width, height: height, bytes: difference)
  }

  private static func image(width: Int, height: Int, bytes: [UInt8]) -> CGImage? {
    let bytesPerRow = width * 4
    var rows = [UInt8]()
    rows.reserveCapacity(bytes.count)
    for row in (0 ..< height).reversed() {
      rows.append(contentsOf: bytes[row * bytesPerRow ..< (row + 1) * bytesPerRow])
    }

    guard let provider = CGDataProvider(data: Data(rows) as CFData), let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
      return nil
    }

    return CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    )
  }
}
