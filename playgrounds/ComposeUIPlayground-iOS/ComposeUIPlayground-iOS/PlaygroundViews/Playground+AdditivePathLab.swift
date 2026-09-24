//
//  Playground+AdditivePathLab.swift
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

  /// A lab for additive path animations.
  ///
  /// A shape layer draws the outline of a rounded rect made from its size. An update animates its frame additively and
  /// its path with `animatePath(keyPath:to:timing:)`, with the same timing, or sets both without animation, the path
  /// with `setPath(keyPath:to:)`. Behind it, a reference layer gets the same frame and corner radius, which Core
  /// Animation animates additively on its own. So an additive path stays on the reference's edge however the updates
  /// interrupt each other. The status measures it on every frame: the drift is how far the path shown is from the
  /// rounded rect of the size and corner radius the reference shows.
  final class AdditivePathLab: BaseView {

    /// The area the layers are centered in.
    private let stage = BaseView()

    /// The layer Core Animation animates on its own: its frame and its corner radius, both additively.
    private let referenceLayer = CALayer()

    /// The layer whose path animates additively.
    private let pathLayer = CAShapeLayer()

    private lazy var controls = ComposeView { [weak self] in
      self?.controlsContent ?? Empty()
    }

    private lazy var status = ComposeView { [weak self] in
      self?.statusContent ?? Empty()
    }

    /// The size the layers get.
    private var size = Constants.defaultSize

    /// The corner radius asked for. The layers get at most half of the smaller side, see `shownCornerRadius`.
    private var cornerRadius = Constants.defaultCornerRadius

    private var isAnimated = true
    private var duration = Constants.defaultDuration
    private var timingKind = TimingKind.easeInEaseOut
    private var showsReference = true

    /// Whether the layers got their first frame, which needs the stage to have a size.
    private var isInitialized = false

    private var samplingTimer: Timer?

    /// How far the path shown is from the rounded rect of the reference, at the last sample.
    private var drift: CGFloat = 0

    /// The largest drift since an update came to layers at rest.
    private var maxDrift: CGFloat = 0

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

      referenceLayer.backgroundColor = Constants.referenceColor.cgColor
      pathLayer.fillColor = nil
      pathLayer.strokeColor = Constants.pathColor.cgColor
      pathLayer.lineWidth = Constants.pathLineWidth
      pathLayer.contentsScale = Self.screenScale

      let stageLayer = Self.layer(of: stage)
      stageLayer.addSublayer(referenceLayer)
      stageLayer.addSublayer(pathLayer)
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
        referenceLayer.position = center
        pathLayer.position = center
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
      guard let shownPath = pathLayer.presentation()?.path, let shownReference = referenceLayer.presentation() else {
        return
      }

      let referencePath = Self.roundedRect(size: shownReference.bounds.size, cornerRadius: shownReference.cornerRadius)
      drift = Self.maxDistance(between: shownPath, and: referencePath)
      maxDrift = max(maxDrift, drift)

      let isAnimating = self.isAnimating
      if wasAnimating, !isAnimating {
        log("landed, max drift \(Self.describe(points: maxDrift))")
      }
      wasAnimating = isAnimating

      refreshStatusIfChanged()
    }

    private var isAnimating: Bool {
      !(pathLayer.animationKeys() ?? []).isEmpty || !(referenceLayer.animationKeys() ?? []).isEmpty
    }

    // MARK: - Updates

    /// Applies the size and the corner radius, with the timing if animated, or at once.
    private func update(reason: String) {
      apply(animationTiming: isAnimated ? timingKind.timing(duration: duration) : nil, reason: reason)
    }

    /// Applies the size and the corner radius to both layers: the frame first, then the path, as a render pass updates a
    /// renderable.
    private func apply(animationTiming: AnimationTiming?, reason: String) {
      let frame = CGRect(x: stage.bounds.midX - size.width / 2, y: stage.bounds.midY - size.height / 2, width: size.width, height: size.height)
      let radius = shownCornerRadius
      let path = Self.roundedRect(size: size, cornerRadius: radius)

      // a run starts when an update comes to layers at rest, and its largest drift is kept until the next run
      if !isAnimating {
        maxDrift = 0
      }

      if let animationTiming {
        if referenceLayer.frame != frame {
          referenceLayer.animateFrame(to: frame, timing: animationTiming)
          pathLayer.animateFrame(to: frame, timing: animationTiming)
        }
        if referenceLayer.cornerRadius != radius {
          referenceLayer.animate(keyPath: "cornerRadius", to: radius, timing: animationTiming)
        }
        pathLayer.animatePath(keyPath: "path", to: path, timing: animationTiming)
      } else {
        CATransaction.disableAnimations {
          referenceLayer.frame = frame
          referenceLayer.cornerRadius = radius
          pathLayer.frame = frame
        }
        pathLayer.setPath(keyPath: "path", to: path)
      }

      let timingDescription = animationTiming == nil ? "instant" : "\(timingKind.title) \(Self.describe(duration: duration))"
      log("\(reason): \(Self.describe(size)), corner radius \(Self.describe(radius)), \(timingDescription)")
      refreshStatusIfChanged()
    }

    private var shownCornerRadius: CGFloat {
      min(cornerRadius, min(size.width, size.height) / 2)
    }

    /// The largest size that fits the stage.
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

    private func randomize() {
      let maxSize = self.maxSize
      size = CGSize(
        width: CGFloat.random(in: Constants.minSide ... maxSize.width).rounded(),
        height: CGFloat.random(in: Constants.minSide ... maxSize.height).rounded()
      )
      cornerRadius = CGFloat.random(in: 0 ... min(size.width, size.height) / 2).rounded()
      update(reason: "random")
    }

    private func reset() {
      referenceLayer.removeAllAnimations()
      pathLayer.removeAllAnimations()
      size = Constants.defaultSize
      cornerRadius = Constants.defaultCornerRadius
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
          button("Radius -\(Int(cornerRadiusStep))") { [weak self] in
            self?.changeCornerRadius(by: -cornerRadiusStep, reason: "radius -\(Int(cornerRadiusStep))")
          }
          button("Radius +\(Int(cornerRadiusStep))") { [weak self] in
            self?.changeCornerRadius(by: cornerRadiusStep, reason: "radius +\(Int(cornerRadiusStep))")
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
          button(isAnimated ? "Animated: on" : "Animated: off") { [weak self] in
            self?.isAnimated.toggle()
          }
          button("Duration: \(Self.describe(duration: duration))") { [weak self] in
            guard let self else {
              return
            }
            self.duration = Constants.durations.first { $0 > self.duration } ?? Constants.durations[0]
          }
          button("Timing: \(timingKind.title)") { [weak self] in
            guard let self else {
              return
            }
            self.timingKind = self.timingKind.next
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button(showsReference ? "Reference: on" : "Reference: off") { [weak self] in
            guard let self else {
              return
            }
            self.showsReference.toggle()
            CATransaction.disableAnimations {
              self.referenceLayer.isHidden = !self.showsReference
            }
          }
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

    private var statusText: String {
      [
        "red outline: animated path, blue fill: Core Animation's reference",
        "size    \(Self.describe(size)), corner radius \(Self.describe(shownCornerRadius))",
        "update  \(isAnimated ? "\(timingKind.title), \(Self.describe(duration: duration))" : "instant")",
        "path    \(pathAnimationDescription)",
        "frames  \(Self.animationCount(of: pathLayer, keyPath: "bounds.size")) on the path layer, \(Self.animationCount(of: referenceLayer, keyPath: "bounds.size")) on the reference",
        "radius  \(Self.animationCount(of: referenceLayer, keyPath: "cornerRadius")) on the reference",
        "drift   \(Self.describe(points: drift)) now, \(Self.describe(points: maxDrift)) max this run",
      ].joined(separator: "\n")
    }

    private var pathAnimationDescription: String {
      switch pathLayer.animation(forKey: "path") {
      case let animation as CAKeyframeAnimation:
        return "keyframes, \(animation.values?.count ?? 0) samples over \(Self.describe(duration: animation.duration))"
      case let animation as CASpringAnimation:
        return "spring over \(Self.describe(duration: animation.duration))"
      case let animation as CABasicAnimation:
        return "basic animation over \(Self.describe(duration: animation.duration))"
      default:
        return "none"
      }
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

    // MARK: - Paths

    /// A rounded rect of the size, made of the same segments for every corner radius, zero included, where
    /// `CGPath(roundedRect:)` makes a plain rect. The corners are the curves Core Graphics draws a quarter circle with.
    ///
    /// The corner radius is at most half of the smaller side, as Core Animation clamps a layer's corner radius.
    static func roundedRect(size: CGSize, cornerRadius: CGFloat) -> CGPath {
      let rect = CGRect(origin: .zero, size: size)
      let radius = min(max(cornerRadius, 0), rect.width / 2, rect.height / 2)

      // the curve's control points are this far from the corner
      let control = radius * (1 - Constants.quarterCircleControlRatio)

      let path = CGMutablePath()
      path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
      path.addCurve(
        to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
        control1: CGPoint(x: rect.maxX, y: rect.maxY - control),
        control2: CGPoint(x: rect.maxX - control, y: rect.maxY)
      )
      path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
      path.addCurve(
        to: CGPoint(x: rect.minX, y: rect.maxY - radius),
        control1: CGPoint(x: rect.minX + control, y: rect.maxY),
        control2: CGPoint(x: rect.minX, y: rect.maxY - control)
      )
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
      path.addCurve(
        to: CGPoint(x: rect.minX + radius, y: rect.minY),
        control1: CGPoint(x: rect.minX, y: rect.minY + control),
        control2: CGPoint(x: rect.minX + control, y: rect.minY)
      )
      path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
      path.addCurve(
        to: CGPoint(x: rect.maxX, y: rect.minY + radius),
        control1: CGPoint(x: rect.maxX - control, y: rect.minY),
        control2: CGPoint(x: rect.maxX, y: rect.minY + control)
      )
      path.closeSubpath()
      return path
    }

    /// The largest distance between the points of two paths, or infinity when they have different numbers of points.
    private static func maxDistance(between path: CGPath, and otherPath: CGPath) -> CGFloat {
      let pathPoints = points(of: path)
      let otherPathPoints = points(of: otherPath)
      guard pathPoints.count == otherPathPoints.count else {
        return .infinity
      }
      return zip(pathPoints, otherPathPoints).reduce(0) { max($0, hypot($1.0.x - $1.1.x, $1.0.y - $1.1.y)) }
    }

    /// The points of a path's segments, in order.
    private static func points(of path: CGPath) -> [CGPoint] {
      var points: [CGPoint] = []
      path.applyWithBlock { element in
        let element = element.pointee
        let pointCount: Int
        switch element.type {
        case .moveToPoint,
             .addLineToPoint:
          pointCount = 1
        case .addQuadCurveToPoint:
          pointCount = 2
        case .addCurveToPoint:
          pointCount = 3
        case .closeSubpath:
          pointCount = 0
        @unknown default:
          pointCount = 0
        }
        points.append(contentsOf: UnsafeBufferPointer(start: element.points, count: pointCount))
      }
      return points
    }

    // MARK: - Helpers

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

    private static func describe(duration: TimeInterval) -> String {
      duration.rounded() == duration ? "\(Int(duration))s" : String(format: "%.1fs", duration)
    }

    private static func describe(points: CGFloat) -> String {
      points.isFinite ? String(format: "%.2f pt", points) : "segments differ"
    }

    private static func layer(of view: View) -> CALayer {
      #if canImport(AppKit)
      return view.layer! // swiftlint:disable:this force_unwrapping
      #else
      return view.layer
      #endif
    }

    private static var screenScale: CGFloat {
      #if canImport(AppKit)
      return NSScreen.main?.backingScaleFactor ?? 2
      #else
      return UIScreen.main.scale
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

    enum Constants {

      static let padding: CGFloat = 12
      static let sectionSpacing: CGFloat = 12
      static let controlSpacing: CGFloat = 6
      static let controlHeight: CGFloat = 30
      static let controlFontSize: CGFloat = 11
      static let controlsHeight: CGFloat = controlHeight * 4 + controlSpacing * 3
      static let statusFontSize: CGFloat = 11
      static let statusSpacing: CGFloat = 6
      static let statusHeight: CGFloat = 200
      static let dividerHeight: CGFloat = 1
      static let logLineCount = 4

      static let defaultSize = CGSize(width: 200, height: 140)
      static let defaultCornerRadius: CGFloat = 16
      static let sizeStep: CGFloat = 40
      static let cornerRadiusStep: CGFloat = 8
      static let minSide: CGFloat = 40
      static let stageMargin: CGFloat = 12

      static let durations: [TimeInterval] = [0.5, 1, 2, 5]
      static let defaultDuration: TimeInterval = 2
      static let springDampingRatio: CGFloat = 0.5

      static let referenceColor = Color(red: 0.25, green: 0.55, blue: 0.95, alpha: 0.35)
      static let pathColor = Colors.RetroApple.red
      static let pathLineWidth: CGFloat = 2
      static let samplingInterval: TimeInterval = 1.0 / 60

      /// How far along its end tangents a cubic curve's control points sit to draw a quarter circle, as a fraction of the
      /// radius: 4/3 × tan(π/8).
      static let quarterCircleControlRatio: CGFloat = 0.5522847498
    }
  }
}
