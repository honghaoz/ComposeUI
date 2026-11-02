//
//  Playground+ShadowLab.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/24/26.
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

@_spi(Private) import ComposeUI

extension Playground {

  /// A lab for `DropShadowLayer` and `InnerShadowLayer`.
  ///
  /// A card sits between a drop shadow under it and an inner shadow over it, all three with the same frame, as the shadow
  /// nodes' renderables sit with the node they decorate. An update animates the frames additively and updates the
  /// shadows with the same timing, or sets everything without animation, the way a render pass updates a renderable. The
  /// status measures on every frame how far each shadow path is from the card: the drift is the largest distance between
  /// the edges of the path's bounds and the card's.
  final class ShadowLab: BaseView {

    /// The area the layers are centered in.
    private let stage = BaseView()

    private let dropShadowLayer = DropShadowLayer()

    /// The shape the shadows belong to.
    private let cardLayer = CALayer()

    private let innerShadowLayer = InnerShadowLayer()

    private var layers: [CALayer] {
      [dropShadowLayer, cardLayer, innerShadowLayer]
    }

    private lazy var controls = ComposeView { [weak self] in
      self?.controlsContent ?? Empty()
    }

    private lazy var status = ComposeView { [weak self] in
      self?.statusContent ?? Empty()
    }

    private var size = Constants.defaultSize

    /// The corner radius asked for. The card gets at most half of the smaller side, see `shownCornerRadius`.
    private var cornerRadius = Constants.defaultCornerRadius

    private var shadowRadius = Constants.defaultShadowRadius
    private var offset = Constants.defaultOffset
    private var opacity = Constants.defaultOpacity
    private var colorIndex = 0

    /// Whether the drop shadow is clipped out of the card.
    private var hasCutout = true

    /// How far the inner shadow's hole is inset from the card, which spreads the shadow.
    private var spread: CGFloat = 0

    private var showsDropShadow = true
    private var showsInnerShadow = true
    private var showsCard = true

    private var isAnimated = true
    private var duration = Constants.defaultDuration
    private var timingKind = TimingKind.easeInEaseOut

    /// Whether the layers got their first frame, which needs the stage to have a size.
    private var isInitialized = false

    private var samplingTimer: Timer?

    /// How far each path is from the card at the last sample.
    private var drift = Drift()

    /// The largest drift of each path since an update came to layers at rest.
    private var maxDrift = Drift()

    /// Whether any layer was animating at the last sample, to log when a run lands.
    private var wasAnimating = false

    private var logLines: [String] = []
    private var lastStatusText = ""

    private let timeFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "mm:ss.SSS"
      return formatter
    }()

    override init(frame: CGRect) {
      super.init(frame: frame)

      #if canImport(AppKit)
      wantsLayer = true
      stage.wantsLayer = true
      #endif

      addSubview(controls)
      addSubview(status)
      addSubview(stage)

      status.clippingBehavior = .always

      cardLayer.backgroundColor = Constants.cardColor.cgColor
      cardLayer.borderColor = Constants.cardBorderColor.cgColor
      cardLayer.borderWidth = Constants.cardBorderWidth

      let stageLayer = Self.layer(of: stage)
      stageLayer.backgroundColor = Constants.stageColor.cgColor
      for layer in layers {
        stageLayer.addSublayer(layer)
      }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
    }

    deinit {
      samplingTimer?.invalidate()
    }

    // MARK: - Layout

    override func layoutSubviews() {
      super.layoutSubviews()

      let padding = Constants.padding
      let width = bounds.width - padding * 2
      var y = padding

      controls.frame = CGRect(x: padding, y: y, width: width, height: Constants.controlsHeight)
      y += Constants.controlsHeight + Constants.sectionSpacing

      status.frame = CGRect(x: padding, y: y, width: width, height: Constants.statusHeight)
      y += Constants.statusHeight + Constants.sectionSpacing

      stage.frame = CGRect(x: padding, y: y, width: width, height: max(bounds.height - y - padding, 0))

      if isInitialized {
        centerLayers()
      } else if stage.bounds.width > 0, stage.bounds.height > 0 {
        isInitialized = true
        apply(animationTiming: nil, reason: "start")
      }
    }

    /// Moves the layers to the stage's center without animation, keeping their animations, as the stage resizes.
    private func centerLayers() {
      let center = CGPoint(x: stage.bounds.midX, y: stage.bounds.midY)
      CATransaction.disableAnimations {
        for layer in layers {
          layer.position = center
        }
      }
    }

    // MARK: - Sampling

    #if canImport(AppKit)
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      updateSampling()
    }
    #else
    override func didMoveToWindow() {
      super.didMoveToWindow()
      updateSampling()
    }
    #endif

    /// Samples the drift on every frame while the lab is in a window.
    private func updateSampling() {
      guard window != nil else {
        samplingTimer?.invalidate()
        samplingTimer = nil
        return
      }

      guard samplingTimer == nil else {
        return
      }

      let timer = Timer(timeInterval: Constants.samplingInterval, repeats: true) { [weak self] _ in
        self?.sample()
      }
      RunLoop.main.add(timer, forMode: .common)
      samplingTimer = timer
    }

    private func sample() {
      guard let cardFrame = cardLayer.presentation()?.frame else {
        return
      }

      let cutoutBounds = Self.shownMaskPathBounds(of: dropShadowLayer).map { $0.insetBy(dx: Constants.maskMargin, dy: Constants.maskMargin) }
      drift = Drift(
        dropPath: Self.shownShadowPathBounds(of: dropShadowLayer).map { Self.distance(between: $0, and: cardFrame) },
        cutout: cutoutBounds.map { Self.distance(between: $0, and: cardFrame) },
        hole: Self.shownShadowPathBounds(of: innerShadowLayer).map { Self.distance(between: $0, and: cardFrame.insetBy(dx: spread, dy: spread)) },
        clip: Self.shownMaskPathBounds(of: innerShadowLayer).map { Self.distance(between: $0, and: cardFrame) }
      )
      maxDrift = maxDrift.combined(with: drift)

      let isAnimating = self.isAnimating
      if wasAnimating, !isAnimating {
        log("landed, max drift (drop, cutout, hole, clip) \(Self.describe(maxDrift)) pt")
      }
      wasAnimating = isAnimating

      refreshStatusIfChanged()
    }

    private var isAnimating: Bool {
      let layers: [CALayer?] = [cardLayer, dropShadowLayer, dropShadowLayer.mask, innerShadowLayer, innerShadowLayer.mask]
      return layers.contains { $0?.animationKeys()?.isEmpty == false }
    }

    // MARK: - Updates

    /// Applies the card and the shadows, with the timing if animated, or at once.
    private func update(reason: String) {
      apply(animationTiming: isAnimated ? timingKind.timing(duration: duration) : nil, reason: reason)
    }

    /// Applies the card and the shadows: the frames first, then the shadows, as a render pass updates a renderable.
    private func apply(animationTiming: AnimationTiming?, reason: String) {
      let frame = CGRect(x: stage.bounds.midX - size.width / 2, y: stage.bounds.midY - size.height / 2, width: size.width, height: size.height)
      let cornerRadius = shownCornerRadius
      let spread = self.spread
      let hasCutout = self.hasCutout
      let color = Constants.colors[colorIndex].color

      // a run starts when an update comes to layers at rest, and its largest drift is kept until the next run
      if !isAnimating {
        maxDrift = Drift()
      }

      // implicit actions are off for the whole update, which leaves the explicit animations the framework adds alone
      CATransaction.disableAnimations {
        for layer in layers where layer.frame != frame {
          if let animationTiming {
            layer.animateFrame(to: frame, timing: animationTiming)
          } else {
            layer.frame = frame
          }
        }

        if cardLayer.cornerRadius != cornerRadius {
          if let animationTiming {
            cardLayer.animate(keyPath: "cornerRadius", to: cornerRadius, timing: animationTiming)
          } else {
            cardLayer.cornerRadius = cornerRadius
          }
        }

        dropShadowLayer.update(
          color: color,
          opacity: opacity,
          radius: shadowRadius,
          offset: offset,
          paths: { size in
            let shape = Self.roundedRect(size: size, cornerRadius: cornerRadius)
            return DropShadowPaths(shadowPath: shape, cutoutPath: hasCutout ? shape : nil)
          },
          animationTiming: animationTiming
        )

        innerShadowLayer.update(
          color: color,
          opacity: opacity,
          radius: shadowRadius,
          offset: offset,
          paths: { size in
            InnerShadowPaths(
              shadowPath: Self.roundedRect(size: size, cornerRadius: cornerRadius, inset: spread),
              clipPath: Self.roundedRect(size: size, cornerRadius: cornerRadius)
            )
          },
          animationTiming: animationTiming
        )
      }

      let timingDescription = animationTiming == nil ? "instant" : "\(timingKind.title) \(Self.describe(duration: duration))"
      log("\(reason): \(Self.describe(size)), corner \(Self.describe(cornerRadius)), \(shadowDescription), \(timingDescription)")
      refreshStatusIfChanged()
    }

    private var shownCornerRadius: CGFloat {
      min(cornerRadius, min(size.width, size.height) / 2)
    }

    /// The largest size that fits the stage, with room around it for the drop shadow.
    private var maxSize: CGSize {
      CGSize(
        width: max(stage.bounds.width - Constants.stageMargin * 2, Constants.minSide),
        height: max(stage.bounds.height - Constants.stageMargin * 2, Constants.minSide)
      )
    }

    private func resize(by delta: CGSize, reason: String) {
      let maxSize = self.maxSize
      size = CGSize(
        width: min(max(size.width + delta.width, Constants.minSide), maxSize.width),
        height: min(max(size.height + delta.height, Constants.minSide), maxSize.height)
      )
      update(reason: reason)
    }

    private func changeCornerRadius(by delta: CGFloat, reason: String) {
      cornerRadius = min(max(cornerRadius + delta, 0), min(size.width, size.height) / 2)
      update(reason: reason)
    }

    /// Changes the card and the shadow at once, as an update that changes several inputs does.
    private func randomize() {
      let maxSize = self.maxSize
      size = CGSize(
        width: CGFloat.random(in: Constants.minSide ... maxSize.width).rounded(),
        height: CGFloat.random(in: Constants.minSide ... maxSize.height).rounded()
      )
      cornerRadius = CGFloat.random(in: 0 ... min(size.width, size.height) / 2).rounded()
      shadowRadius = Constants.shadowRadii.randomElement() ?? shadowRadius
      offset = Constants.offsets.randomElement() ?? offset
      opacity = Constants.opacities.randomElement() ?? opacity
      spread = Constants.spreads.randomElement() ?? spread
      update(reason: "random")
    }

    private func reset() {
      let layers: [CALayer?] = [cardLayer, dropShadowLayer, dropShadowLayer.mask, innerShadowLayer, innerShadowLayer.mask]
      for layer in layers {
        layer?.removeAllAnimations()
      }
      size = Constants.defaultSize
      cornerRadius = Constants.defaultCornerRadius
      shadowRadius = Constants.defaultShadowRadius
      offset = Constants.defaultOffset
      opacity = Constants.defaultOpacity
      colorIndex = 0
      hasCutout = true
      spread = 0
      apply(animationTiming: nil, reason: "reset")
    }

    // MARK: - Controls

    @ComposeContentBuilder
    private var controlsContent: ComposeContent {
      let sizeStep = Constants.sizeStep
      let cornerRadiusStep = Constants.cornerRadiusStep

      VStack(spacing: Constants.controlSpacing) {
        HStack(spacing: Constants.controlSpacing) {
          button("Width -\(Int(sizeStep))") { [weak self] in
            self?.resize(by: CGSize(width: -sizeStep, height: 0), reason: "width -\(Int(sizeStep))")
          }
          button("Width +\(Int(sizeStep))") { [weak self] in
            self?.resize(by: CGSize(width: sizeStep, height: 0), reason: "width +\(Int(sizeStep))")
          }
          button("Height -\(Int(sizeStep))") { [weak self] in
            self?.resize(by: CGSize(width: 0, height: -sizeStep), reason: "height -\(Int(sizeStep))")
          }
          button("Height +\(Int(sizeStep))") { [weak self] in
            self?.resize(by: CGSize(width: 0, height: sizeStep), reason: "height +\(Int(sizeStep))")
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button("Corner -\(Int(cornerRadiusStep))") { [weak self] in
            self?.changeCornerRadius(by: -cornerRadiusStep, reason: "corner -\(Int(cornerRadiusStep))")
          }
          button("Corner +\(Int(cornerRadiusStep))") { [weak self] in
            self?.changeCornerRadius(by: cornerRadiusStep, reason: "corner +\(Int(cornerRadiusStep))")
          }
          button("Random") { [weak self] in
            self?.randomize()
          }
          button("Reset") { [weak self] in
            self?.reset()
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button("Blur: \(Self.describe(shadowRadius))") { [weak self] in
            guard let self else {
              return
            }
            self.shadowRadius = Self.value(after: self.shadowRadius, in: Constants.shadowRadii)
            self.update(reason: "blur")
          }
          button("Offset: \(Self.describe(offset: offset))") { [weak self] in
            guard let self else {
              return
            }
            self.offset = Self.value(after: self.offset, in: Constants.offsets)
            self.update(reason: "offset")
          }
          button("Opacity: \(Self.describe(opacity: opacity))") { [weak self] in
            guard let self else {
              return
            }
            self.opacity = Self.value(after: self.opacity, in: Constants.opacities)
            self.update(reason: "opacity")
          }
          button("Color: \(Constants.colors[colorIndex].title)") { [weak self] in
            guard let self else {
              return
            }
            self.colorIndex = (self.colorIndex + 1) % Constants.colors.count
            self.update(reason: "color")
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button("Drop: \(Self.onOff(showsDropShadow))") { [weak self] in
            guard let self else {
              return
            }
            self.showsDropShadow.toggle()
            CATransaction.disableAnimations {
              self.dropShadowLayer.isHidden = !self.showsDropShadow
            }
          }
          button("Cutout: \(Self.onOff(hasCutout))") { [weak self] in
            guard let self else {
              return
            }
            self.hasCutout.toggle()
            self.update(reason: "cutout \(Self.onOff(self.hasCutout))")
          }
          button("Inner: \(Self.onOff(showsInnerShadow))") { [weak self] in
            guard let self else {
              return
            }
            self.showsInnerShadow.toggle()
            CATransaction.disableAnimations {
              self.innerShadowLayer.isHidden = !self.showsInnerShadow
            }
          }
          button("Spread: \(Self.describe(spread))") { [weak self] in
            guard let self else {
              return
            }
            self.spread = Self.value(after: self.spread, in: Constants.spreads)
            self.update(reason: "spread")
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button("Animated: \(Self.onOff(isAnimated))") { [weak self] in
            self?.isAnimated.toggle()
          }
          button("Duration: \(Self.describe(duration: duration))") { [weak self] in
            guard let self else {
              return
            }
            self.duration = Self.value(after: self.duration, in: Constants.durations)
          }
          button("Timing: \(timingKind.title)") { [weak self] in
            guard let self else {
              return
            }
            self.timingKind = self.timingKind.next
          }
          button("Card: \(Self.onOff(showsCard))") { [weak self] in
            guard let self else {
              return
            }
            self.showsCard.toggle()
            CATransaction.disableAnimations {
              self.cardLayer.isHidden = !self.showsCard
            }
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button("Copy log") { [weak self] in
            self?.copyLog()
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)
      }
    }

    private func button(_ title: String, onTap: @escaping () -> Void) -> ComposeNode {
      Playground.button(title: title, fontSize: Constants.controlFontSize) { [weak self] in
        onTap()
        self?.controls.refresh(animated: false)
        self?.refreshStatusIfChanged()
      }
    }

    // MARK: - Status

    /// The state above a divider, the latest log lines below it.
    private var statusContent: ComposeContent {
      VStack(spacing: Constants.statusSpacing) {
        statusLabel(statusText, color: Self.labelColor)
        ColorNode(Colors.blueGray)
          .frame(width: .flexible, height: Constants.dividerHeight)
        ComposeViewNode {
          statusLabel(logText, color: Self.secondaryLabelColor)
            .frame(width: .flexible, height: .flexible, alignment: .bottomLeft)
        }
        .flexibleSize()
        .willInsert { renderable, _ in
          // the content is never larger than the view, so the default clipping would leave the overflow visible
          (renderable.view as? ComposeView)?.clippingBehavior = .always
        }
      }
    }

    /// The state, in lines short enough for a phone's width.
    private var statusText: String {
      [
        "card: white, drop shadow under, inner shadow over",
        "card    \(Self.describe(size)), corner \(Self.describe(shownCornerRadius))",
        "shadow  \(shadowDescription)",
        "update  \(isAnimated ? "\(timingKind.title), \(Self.describe(duration: duration))" : "instant")",
        "drop    path \(Self.describePathAnimation(of: dropShadowLayer, key: "shadowPath")), cutout \(dropShadowLayer.mask.map { Self.describePathAnimation(of: $0, key: "path") } ?? "off")",
        "inner   hole \(Self.describePathAnimation(of: innerShadowLayer, key: "shadowPath")), clip \(innerShadowLayer.mask.map { Self.describePathAnimation(of: $0, key: "path") } ?? "none")",
        "frames  card \(Self.animationCount(of: cardLayer, keyPath: "bounds.size")), drop \(Self.animationCount(of: dropShadowLayer, keyPath: "bounds.size")), inner \(Self.animationCount(of: innerShadowLayer, keyPath: "bounds.size"))",
        "drift   drop, cutout, hole, clip (pt)",
        "now     \(Self.describe(drift))",
        "max     \(Self.describe(maxDrift)) since at rest",
      ].joined(separator: "\n")
    }

    private var shadowDescription: String {
      "\(Constants.colors[colorIndex].title) \(Self.describe(opacity: opacity)), blur \(Self.describe(shadowRadius)), offset \(Self.describe(offset: offset)), spread \(Self.describe(spread))"
    }

    private var logText: String {
      (["log"] + logLines.suffix(Constants.logLineCount)).joined(separator: "\n")
    }

    private func statusLabel(_ text: String, color: Color) -> ComposeNode {
      Label(text)
        .font(.monospacedSystemFont(ofSize: Constants.statusFontSize, weight: .regular))
        .textColor(color)
        .numberOfLines(0)
        .lineBreakMode(.byTruncatingTail)
        .textAlignment(.left)
        .selectable(false)
        .fixedSize(width: false, height: true)
    }

    /// Refreshes the status when its text changed, which happens on every frame while the layers animate.
    private func refreshStatusIfChanged() {
      let text = statusText + logText
      guard text != lastStatusText else {
        return
      }
      lastStatusText = text
      status.setNeedsRefresh(animated: false)
    }

    private func log(_ message: String) {
      logLines.append("\(timeFormatter.string(from: Date())) \(message)")
      refreshStatusIfChanged()
    }

    private func copyLog() {
      let text = logLines.joined(separator: "\n")
      #if canImport(AppKit)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
      #else
      UIPasteboard.general.string = text
      #endif
      log("copied \(logLines.count) log lines")
    }

    // MARK: - Drift

    /// How far each shadow path is from the card, in points, or `nil` for a path the shadow doesn't have.
    ///
    /// A spread change shows as drift of the hole while it animates, as the card has no spread to follow.
    private struct Drift {

      let dropPath: CGFloat?
      let cutout: CGFloat?
      let hole: CGFloat?
      let clip: CGFloat?

      init(dropPath: CGFloat? = nil, cutout: CGFloat? = nil, hole: CGFloat? = nil, clip: CGFloat? = nil) {
        self.dropPath = dropPath
        self.cutout = cutout
        self.hole = hole
        self.clip = clip
      }

      /// The larger drift of each path.
      func combined(with other: Drift) -> Drift {
        Drift(
          dropPath: Self.max(dropPath, other.dropPath),
          cutout: Self.max(cutout, other.cutout),
          hole: Self.max(hole, other.hole),
          clip: Self.max(clip, other.clip)
        )
      }

      private static func max(_ value: CGFloat?, _ other: CGFloat?) -> CGFloat? {
        guard let value else {
          return other
        }
        guard let other else {
          return value
        }
        return Swift.max(value, other)
      }
    }

    /// The bounds of the shadow path a layer shows, in the stage's coordinates.
    private static func shownShadowPathBounds(of layer: CALayer) -> CGRect? {
      guard let shownLayer = layer.presentation(), let path = shownLayer.shadowPath else {
        return nil
      }
      return path.boundingBoxOfPath.offsetBy(dx: shownLayer.frame.minX, dy: shownLayer.frame.minY)
    }

    /// The bounds of the path a layer's mask shows, in the stage's coordinates.
    private static func shownMaskPathBounds(of layer: CALayer) -> CGRect? {
      guard let shownLayer = layer.presentation(), let shownMask = (layer.mask as? CAShapeLayer)?.presentation(), let path = shownMask.path else {
        return nil
      }
      return path.boundingBoxOfPath.offsetBy(dx: shownLayer.frame.minX + shownMask.frame.minX, dy: shownLayer.frame.minY + shownMask.frame.minY)
    }

    /// The largest distance between the edges of two rects.
    private static func distance(between rect: CGRect, and otherRect: CGRect) -> CGFloat {
      max(
        abs(rect.minX - otherRect.minX),
        abs(rect.minY - otherRect.minY),
        abs(rect.maxX - otherRect.maxX),
        abs(rect.maxY - otherRect.maxY)
      )
    }

    // MARK: - Paths

    /// A rounded rect of the size, inset by the inset with its corner radius less the inset, made of the same segments
    /// for every corner radius, so a corner radius change animates too, see
    /// `AdditivePathLab.roundedRect(size:cornerRadius:)`.
    private static func roundedRect(size: CGSize, cornerRadius: CGFloat, inset: CGFloat = 0) -> CGPath {
      let insetSize = CGSize(width: max(size.width - inset * 2, 0), height: max(size.height - inset * 2, 0))
      let path = AdditivePathLab.roundedRect(size: insetSize, cornerRadius: max(cornerRadius - inset, 0))
      var transform = CGAffineTransform(translationX: inset, y: inset)
      return path.copy(using: &transform) ?? path
    }

    // MARK: - Describing

    private static func describePathAnimation(of layer: CALayer, key: String) -> String {
      switch layer.animation(forKey: key) {
      case let animation as CAKeyframeAnimation:
        return "keyframes \(describe(duration: animation.duration))"
      case let animation as CASpringAnimation:
        return "spring \(describe(duration: animation.duration))"
      case let animation as CABasicAnimation:
        return "basic \(describe(duration: animation.duration))"
      default:
        return "at rest"
      }
    }

    private static func describe(_ drift: Drift) -> String {
      [drift.dropPath, drift.cutout, drift.hole, drift.clip].map { describe(points: $0) }.joined(separator: ", ")
    }

    private static func describe(points: CGFloat?) -> String {
      points.map { String(format: "%.2f", $0) } ?? "-"
    }

    /// The number of animations of a key path on a layer.
    private static func animationCount(of layer: CALayer, keyPath: String) -> Int {
      (layer.animationKeys() ?? []).filter { (layer.animation(forKey: $0) as? CAPropertyAnimation)?.keyPath == keyPath }.count
    }

    private static func describe(_ size: CGSize) -> String {
      "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    private static func describe(_ value: CGFloat) -> String {
      String(format: "%.0f", value)
    }

    private static func describe(offset: CGSize) -> String {
      "\(describe(offset.width)),\(describe(offset.height))"
    }

    private static func describe(opacity: CGFloat) -> String {
      String(format: "%.1f", opacity)
    }

    private static func describe(duration: TimeInterval) -> String {
      duration.rounded() == duration ? "\(Int(duration))s" : String(format: "%.1fs", duration)
    }

    private static func onOff(_ isOn: Bool) -> String {
      isOn ? "on" : "off"
    }

    // MARK: - Helpers

    /// The value after a value in a list, wrapping around, or the first value when the list doesn't have it.
    private static func value<T: Equatable>(after value: T, in values: [T]) -> T {
      guard let index = values.firstIndex(of: value) else {
        return values[0]
      }
      return values[(index + 1) % values.count]
    }

    private static func layer(of view: View) -> CALayer {
      #if canImport(AppKit)
      return view.layer! // swiftlint:disable:this force_unwrapping
      #else
      return view.layer
      #endif
    }

    private static var labelColor: Color {
      #if canImport(AppKit)
      return .labelColor
      #else
      return .label
      #endif
    }

    private static var secondaryLabelColor: Color {
      #if canImport(AppKit)
      return .secondaryLabelColor
      #else
      return .secondaryLabel
      #endif
    }

    // MARK: - Timing

    private enum TimingKind {

      case linear
      case easeInEaseOut
      case spring

      var title: String {
        switch self {
        case .linear:
          return "linear"
        case .easeInEaseOut:
          return "ease in out"
        case .spring:
          return "spring"
        }
      }

      var next: TimingKind {
        switch self {
        case .linear:
          return .easeInEaseOut
        case .easeInEaseOut:
          return .spring
        case .spring:
          return .linear
        }
      }

      func timing(duration: TimeInterval) -> AnimationTiming {
        switch self {
        case .linear:
          return .linear(duration: duration)
        case .easeInEaseOut:
          return .easeInEaseOut(duration: duration)
        case .spring:
          // a spring settles in about twice its response, so the duration still sets how long it moves
          return .spring(dampingRatio: Constants.springDampingRatio, response: duration / 2)
        }
      }
    }

    // MARK: - Constants

    private enum Constants {

      static let padding: CGFloat = 12
      static let sectionSpacing: CGFloat = 12
      static let controlSpacing: CGFloat = 6
      static let controlHeight: CGFloat = 30
      static let controlFontSize: CGFloat = 11
      static let controlRowCount = 6
      static let controlsHeight: CGFloat = controlHeight * CGFloat(controlRowCount) + controlSpacing * CGFloat(controlRowCount - 1)
      static let statusFontSize: CGFloat = 11
      static let statusSpacing: CGFloat = 6
      static let statusHeight: CGFloat = 230
      static let dividerHeight: CGFloat = 1
      static let logLineCount = 4

      static let defaultSize = CGSize(width: 200, height: 140)
      static let defaultCornerRadius: CGFloat = 16
      static let sizeStep: CGFloat = 40
      static let cornerRadiusStep: CGFloat = 8
      static let minSide: CGFloat = 40

      /// The room around the largest card, for the drop shadow's blur.
      static let stageMargin: CGFloat = 24

      static let shadowRadii: [CGFloat] = [0, 4, 10, 20, 40]
      static let defaultShadowRadius: CGFloat = 10
      static let offsets: [CGSize] = [.zero, CGSize(width: 0, height: 6), CGSize(width: 6, height: 6), CGSize(width: 0, height: -6)]
      static let defaultOffset = CGSize(width: 0, height: 6)
      static let opacities: [CGFloat] = [0.3, 0.6, 1]
      static let defaultOpacity: CGFloat = 0.6
      static let spreads: [CGFloat] = [0, 6, 12]
      static let colors: [(title: String, color: Color)] = [("black", .black), ("red", .red), ("blue", .blue)]

      static let durations: [TimeInterval] = [0.5, 1, 2, 5]
      static let defaultDuration: TimeInterval = 2
      static let springDampingRatio: CGFloat = 0.5

      static let stageColor = Color(white: 0.94, alpha: 1)
      static let cardColor = Color.white
      static let cardBorderColor = Color(white: 0.5, alpha: 1)
      static let cardBorderWidth: CGFloat = 1
      static let samplingInterval: TimeInterval = 1.0 / 60

      /// The margin `DropShadowLayer` pads the cutout with in its mask path, to find the cutout in it.
      static let maskMargin: CGFloat = 1000000
    }
  }
}
