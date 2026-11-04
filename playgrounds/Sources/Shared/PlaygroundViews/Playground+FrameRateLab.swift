//
//  Playground+FrameRateLab.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/2/26.
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

  /// A lab for the frame rate of animations on a display whose refresh rate changes, such as a ProMotion display.
  ///
  /// A box moves across the stage, fades or changes its color, back and forth at a constant rate, with an animation
  /// that `CABasicAnimation.makeAnimation(_:)` makes, as ComposeUI makes its animations. The mode keeps the frame rate
  /// range that ComposeUI sets or replaces it, to compare ComposeUI's animations with the rate that Core Animation
  /// picks for an animation without a range, and with fixed rates.
  ///
  /// Nothing else on the page animates, since the display refreshes at the rate that the fastest animation on screen
  /// asks for, which would hide the box's rate.
  final class FrameRateLab: ComposeView {

    private var property = Property.position

    private var mode = Mode.composeUI

    /// How long the box's animation takes to go one way.
    private var duration = Constants.durations[0]

    /// The view that the box animates in.
    private let stageView = BaseView()

    /// The box, a plain layer that only the lab animates.
    private let box = CALayer()

    /// The size of the stage that the box's animation is for.
    private var stageSize: CGSize = .zero

    private var powerStateObserver: NSObjectProtocol?

    override init(frame: CGRect) {
      super.init(frame: frame)

      animationBehavior = .disabled

      box.backgroundColor = Constants.boxColor.cgColor
      box.cornerRadius = Constants.boxCornerRadius
      stageLayer.addSublayer(box)

      powerStateObserver = NotificationCenter.default.addObserver(
        forName: .NSProcessInfoPowerStateDidChange,
        object: nil,
        queue: .main,
        using: { [weak self] _ in
          self?.refresh(animated: false)
        }
      )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
    }

    deinit {
      if let powerStateObserver {
        NotificationCenter.default.removeObserver(powerStateObserver)
      }
    }

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(alignment: .left, spacing: Constants.spacing) {
        note("Compare 60 Hz with 120 Hz first, then the other modes. A moving box looks smoother at 120 Hz, since it moves half as far between frames. Low Power Mode, a frame rate limit in the settings and a hot device can cap the rate at 60 Hz.")
        note(displayDescription)

        text(statusText, font: .systemFont(ofSize: Constants.statusFontSize, weight: .semibold), color: Colors.darkBlueGray)

        ViewNode(stageView, update: { [weak self] _, context in
          self?.stageDidLayOut(size: context.newFrame.size)
        })
        .flexibleSize()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .frame(width: .flexible, height: Constants.stageHeight)

        HStack(spacing: Constants.buttonSpacing) {
          for property in Property.allCases {
            button(property.title) { $0.property = property }
          }
        }
        .frame(width: .flexible, height: Constants.buttonHeight)

        HStack(spacing: Constants.buttonSpacing) {
          for mode in Mode.allCases {
            button(mode.title) { $0.mode = mode }
          }
        }
        .frame(width: .flexible, height: Constants.buttonHeight)

        HStack(spacing: Constants.buttonSpacing) {
          for duration in Constants.durations {
            button(Self.describe(duration)) { $0.duration = duration }
          }
        }
        .frame(width: .flexible, height: Constants.buttonHeight)
      }
      .padding(Constants.padding)
    }

    private func note(_ text: String) -> some ComposeNode {
      self.text(text, font: .systemFont(ofSize: Constants.noteFontSize), color: Color.gray)
    }

    private func text(_ text: String, font: Font, color: Color) -> some ComposeNode {
      Label(text)
        .font(font)
        .textColor(color)
        .numberOfLines(0)
        .textAlignment(.left)
        .fixedSize(width: false, height: true)
    }

    /// A control that changes the box's animation, then starts the box again with it. The button changes at once when
    /// pressed, so that its animation doesn't raise the display's rate while the box runs.
    private func button(_ title: String, change: @escaping (FrameRateLab) -> Void) -> ComposeNode {
      Playground.button(title: title, fontSize: Constants.buttonFontSize) { [weak self] in
        guard let self else {
          return
        }
        change(self)
        startBox()
        refresh(animated: false)
      }
      .willInsert { renderable, _ in
        (renderable.view as? ButtonView)?.animationBehavior = .disabled
      }
    }

    // MARK: - Status

    /// The display's highest refresh rate and the settings that the box's rate depends on.
    private var displayDescription: String {
      var parts: [String] = []
      if let maximumFrameRate {
        parts.append("Display: up to \(maximumFrameRate) Hz")
      }
      parts.append("Low Power Mode: \(ProcessInfo.processInfo.isLowPowerModeEnabled ? "on" : "off")")
      #if os(iOS)
      // without the key, Core Animation doesn't go above 60 Hz for an iPhone app, while an iPad app doesn't need it
      let allowsHighFrameRates = Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") as? Bool ?? false
      parts.append("CADisableMinimumFrameDurationOnPhone: \(allowsHighFrameRates ? "YES" : "NO")")
      #endif
      return parts.joined(separator: ", ")
    }

    /// The highest refresh rate of the display that shows the lab, `nil` when there's no display to ask.
    private var maximumFrameRate: Int? {
      #if canImport(AppKit)
      return window?.screen?.maximumFramesPerSecond
      #elseif os(visionOS)
      return nil
      #else
      return window?.windowScene?.screen.maximumFramesPerSecond
      #endif
    }

    /// The frame rate range and the pace of the box's animation.
    private var statusText: String {
      var text = "\(mode.title): \(Self.describe(makeAnimation().preferredFrameRateRange))\n"
      text += "\(property.title), \(Self.describe(duration)) each way"
      switch property {
      case .position:
        let distance = crossingEnds.right - crossingEnds.left
        if distance > 0 {
          text += String(format: ", %.0f pt/s", distance / duration)
        }
      case .opacity,
           .color:
        break
      }
      return text
    }

    private static func describe(_ range: CAFrameRateRange) -> String {
      guard range != .default else {
        return "Core Animation picks the rate"
      }
      let rates = "\(describe(range.minimum)) to \(describe(range.maximum)) Hz"
      guard let preferred = range.preferred else {
        return rates
      }
      return "\(rates), preferred \(describe(preferred))"
    }

    private static func describe(_ rate: Float) -> String {
      String(format: "%g", Double(rate))
    }

    private static func describe(_ duration: TimeInterval) -> String {
      String(format: "%g s", duration)
    }

    // MARK: - Box

    private var stageLayer: CALayer {
      #if canImport(AppKit)
      return stageView.layer! // swiftlint:disable:this force_unwrapping
      #else
      return stageView.layer
      #endif
    }

    /// The x coordinates of the box's center at the stage's left and right ends.
    private var crossingEnds: (left: CGFloat, right: CGFloat) {
      let left = Constants.boxInset + Constants.boxSize / 2
      return (left, stageSize.width - left)
    }

    /// Starts the box again when the stage's size changes, so that a move crosses the whole stage.
    private func stageDidLayOut(size: CGSize) {
      guard size != stageSize else {
        return
      }
      stageSize = size
      startBox()
      // the status shows the box's speed, which depends on the stage's width
      setNeedsRefresh(animated: false)
    }

    /// Starts the box's animation of the selected property and mode, back and forth until the next start. A move goes
    /// from the stage's left end, while a fade or a color change runs in the stage's center.
    private func startBox() {
      box.removeAllAnimations()

      let ends = crossingEnds
      let center = CGPoint(x: stageSize.width / 2, y: stageSize.height / 2)
      let animation = makeAnimation()
      let position: CGPoint
      switch property {
      case .position:
        position = CGPoint(x: ends.left, y: center.y)
        animation.keyPath = "position.x"
        animation.fromValue = ends.left
        animation.toValue = ends.right
      case .opacity:
        position = center
        animation.keyPath = "opacity"
        animation.fromValue = 1
        animation.toValue = 0
      case .color:
        position = center
        animation.keyPath = "backgroundColor"
        animation.fromValue = Constants.boxColor.cgColor
        animation.toValue = Constants.changedBoxColor.cgColor
      }

      CATransaction.disableAnimations {
        box.bounds = CGRect(x: 0, y: 0, width: Constants.boxSize, height: Constants.boxSize)
        box.position = position
      }
      // the stage isn't laid out yet, or is too narrow for the box
      guard ends.right > ends.left else {
        return
      }

      animation.autoreverses = true
      animation.repeatCount = .infinity
      // an iOS app going to the background removes the animations that would be removed on completion
      animation.isRemovedOnCompletion = false
      box.add(animation, forKey: animation.keyPath)
    }

    /// An animation that ComposeUI makes for a linear change, with the frame rate range of the selected mode.
    private func makeAnimation() -> CABasicAnimation {
      let animation = CABasicAnimation.makeAnimation(.linear(duration: duration))
      if let frameRateRange = mode.frameRateRange {
        animation.preferredFrameRateRange = frameRateRange
      }
      return animation
    }

    // MARK: - Property

    /// The property that the box's animation changes.
    private enum Property: CaseIterable {

      /// The box crosses the stage.
      case position

      /// The box fades out and back in.
      case opacity

      /// The box changes to another color and back.
      case color

      var title: String {
        switch self {
        case .position:
          return "Move"
        case .opacity:
          return "Fade"
        case .color:
          return "Color"
        }
      }
    }

    // MARK: - Mode

    /// The frame rate range that the box's animation asks for.
    private enum Mode: CaseIterable {

      /// The range that ComposeUI's animations have.
      case composeUI

      /// No range, which leaves the rate to Core Animation.
      case noRange

      /// A range that holds the rate at 60 Hz.
      case fixed60Hz

      /// The range that Apple suggests for high-impact animations, which asks for 120 Hz.
      case upTo120Hz

      var title: String {
        switch self {
        case .composeUI:
          return "ComposeUI"
        case .noRange:
          return "No range"
        case .fixed60Hz:
          return "60 Hz"
        case .upTo120Hz:
          return "120 Hz"
        }
      }

      /// The range that the mode sets on the animation, `nil` to keep the range that ComposeUI sets.
      var frameRateRange: CAFrameRateRange? {
        switch self {
        case .composeUI:
          return nil
        case .noRange:
          return .default
        case .fixed60Hz:
          return CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        case .upTo120Hz:
          return CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        }
      }
    }

    // MARK: - Constants

    private enum Constants {

      /// The times the box's animation can take to go one way, the first of which it starts with. A slower move hardly
      /// shows the difference between 60 Hz and 120 Hz.
      static let durations: [TimeInterval] = [0.5, 1]

      static let padding: CGFloat = 16
      static let spacing: CGFloat = 12
      static let noteFontSize: CGFloat = 12
      static let statusFontSize: CGFloat = 15

      static let stageHeight: CGFloat = 120
      static let boxSize: CGFloat = 44
      static let boxCornerRadius: CGFloat = 8
      static let boxColor = Colors.RetroApple.orange

      /// The color that a color change changes the box to.
      static let changedBoxColor = Colors.RetroApple.purple

      /// The space between the box and the stage's ends.
      static let boxInset: CGFloat = 12

      static let buttonHeight: CGFloat = 32
      static let buttonSpacing: CGFloat = 8
      static let buttonFontSize: CGFloat = 13
    }
  }
}
