//
//  Playground+FrameGlideView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

import ComposeUI

extension Playground {

  /// A page for frame changes without animation while a frame animates.
  ///
  /// A card with a drop shadow and an inner shadow grows, shrinks, moves and resizes through the render pass, with an
  /// animated or a non-animated refresh. A non-animated change while the card animates should glide from the frame on
  /// screen to the new frame and land when the animation would have, while a part of the frame at rest, such as the
  /// height during a move, takes its new value at once. The readout shows the card's frame on screen and how far the drop
  /// shadow's path is from it.
  final class FrameGlideView: ComposeView {

    /// The page's preferred height, for the hosting content view's layout.
    static let preferredHeight: CGFloat = 480

    private var cardWidth: CGFloat = Constants.startWidth
    private var cardHeight: CGFloat = Constants.cardHeight
    private var cardTop: CGFloat = Constants.cardTop
    private var isSpring = false

    /// The card's layer, set when the stage renders the card.
    private weak var cardLayer: CALayer?

    private var readout = ""
    private var samplingTimer: Timer?

    private var liveResizeTimer: Timer?
    private var liveResizeStep: CGFloat = 0
    private var liveResizeTicksLeft = 0

    private lazy var stageView = ComposeView { [weak self] in
      self?.stageContent ?? Empty()
    }

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(spacing: 12) {
        Label("Tap Grow, then Shrink now or Live resize while the card is still growing: the card should glide from where it is to the new width and land when the growth would have ended, with its shadows on it. Tap Move down, then Taller now: the new height should apply at once while the move continues. Reset between tries.")
          .font(.systemFont(ofSize: 12))
          .textColor(Color.gray)
          .numberOfLines(0)

        ViewNode(stageView)
          .flexibleSize()
          .underlay {
            LayerNode()
              .border(color: Color.gray, width: 1)
          }
          .frame(width: .flexible, height: Constants.stageHeight)

        HStack(spacing: 8) {
          Playground.button(title: "Grow", fontSize: 12) { [weak self] in
            self?.grow()
          }
          Playground.button(title: "Shrink now", fontSize: 12) { [weak self] in
            self?.shrinkNow()
          }
          Playground.button(title: "Live resize", fontSize: 12) { [weak self] in
            self?.startLiveResize()
          }
        }
        .frame(width: .flexible, height: 36)

        HStack(spacing: 8) {
          Playground.button(title: cardTop == Constants.cardTop ? "Move down" : "Move up", fontSize: 12) { [weak self] in
            self?.move()
          }
          Playground.button(title: cardHeight == Constants.cardHeight ? "Taller now" : "Shorter now", fontSize: 12) { [weak self] in
            self?.toggleHeightNow()
          }
          Playground.button(title: isSpring ? "Spring" : "Linear 4 s", fontSize: 12) { [weak self] in
            self?.toggleTiming()
          }
          Playground.button(title: "Reset", fontSize: 12) { [weak self] in
            self?.reset()
          }
        }
        .frame(width: .flexible, height: 36)

        Label(readout)
          .font(.monospacedDigitSystemFont(ofSize: 11, weight: .regular))
          .textColor(Color.gray)
          .numberOfLines(0)
      }
      .padding(12)
    }

    private var stageContent: ComposeContent {
      LayerNode()
        .overlay(alignment: .topLeft) {
          ColorNode(Colors.RetroApple.orange)
            .cornerRadius(Constants.cornerRadius)
            .onUpdate { [weak self] renderable, _ in
              self?.cardLayer = renderable.layer
            }
            .innerShadow(color: .black, opacity: 0.35, radius: 6, offset: CGSize(width: 0, height: 2), path: { size in
              Self.cardPath(size: size)
            })
            .dropShadow(color: .black, opacity: 0.45, radius: 10, offset: CGSize(width: 0, height: 6), path: { size in
              Self.cardPath(size: size)
            })
            .animation(isSpring ? Constants.springTiming : Constants.linearTiming)
            .frame(width: cardWidth, height: cardHeight)
            .offset(CGPoint(x: Constants.cardLeft, y: cardTop))
        }
    }

    // MARK: - Actions

    private func grow() {
      cardWidth = Constants.grownWidth
      stageView.refresh(animated: true)
    }

    private func shrinkNow() {
      cardWidth = Constants.shrunkWidth
      stageView.refresh(animated: false)
    }

    /// Changes the width without animation in small steps, as dragging a window edge does, toward the other end of the
    /// card's range.
    private func startLiveResize() {
      liveResizeTimer?.invalidate()
      let isWide = cardWidth > (Constants.startWidth + Constants.grownWidth) / 2
      liveResizeStep = isWide ? -Constants.liveResizeStep : Constants.liveResizeStep
      liveResizeTicksLeft = Constants.liveResizeTickCount
      let timer = Timer.scheduledTimer(withTimeInterval: Constants.liveResizeInterval, repeats: true) { [weak self] _ in
        self?.liveResizeTick()
      }
      RunLoop.main.add(timer, forMode: .common)
      liveResizeTimer = timer
    }

    private func liveResizeTick() {
      guard liveResizeTicksLeft > 0 else {
        liveResizeTimer?.invalidate()
        liveResizeTimer = nil
        return
      }
      liveResizeTicksLeft -= 1
      cardWidth = min(max(cardWidth + liveResizeStep, Constants.shrunkWidth), Constants.grownWidth)
      stageView.refresh(animated: false)
    }

    private func move() {
      cardTop = cardTop == Constants.cardTop ? Constants.movedCardTop : Constants.cardTop
      stageView.refresh(animated: true)
      refresh(animated: false)
    }

    private func toggleHeightNow() {
      cardHeight = cardHeight == Constants.cardHeight ? Constants.tallCardHeight : Constants.cardHeight
      stageView.refresh(animated: false)
      refresh(animated: false)
    }

    private func toggleTiming() {
      isSpring.toggle()
      refresh(animated: false)
    }

    /// Puts the card back at its start without animation, after removing every animation in the stage, so each try
    /// starts from the same state.
    private func reset() {
      liveResizeTimer?.invalidate()
      liveResizeTimer = nil
      Self.removeAllAnimations(in: Self.layer(of: stageView))
      cardWidth = Constants.startWidth
      cardHeight = Constants.cardHeight
      cardTop = Constants.cardTop
      stageView.refresh(animated: false)
      refresh(animated: false)
    }

    // MARK: - Readout

    #if canImport(UIKit)
    override func didMoveToWindow() {
      super.didMoveToWindow()
      updateSampling()
    }
    #endif

    #if canImport(AppKit)
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      updateSampling()
    }
    #endif

    deinit {
      samplingTimer?.invalidate()
      liveResizeTimer?.invalidate()
    }

    /// Runs the sampling timer while the page is in a window.
    private func updateSampling() {
      guard window != nil else {
        samplingTimer?.invalidate()
        samplingTimer = nil
        return
      }
      guard samplingTimer == nil else {
        return
      }
      let timer = Timer.scheduledTimer(withTimeInterval: Constants.sampleInterval, repeats: true) { [weak self] _ in
        self?.sample()
      }
      RunLoop.main.add(timer, forMode: .common)
      samplingTimer = timer
    }

    /// Refreshes the page when the readout's text changed, which happens on every sample while the card animates.
    private func sample() {
      let text = readoutText()
      guard text != readout else {
        return
      }
      readout = text
      refresh(animated: false)
    }

    private func readoutText() -> String {
      guard let cardLayer else {
        return "The card isn't rendered yet."
      }
      let shownFrame = (cardLayer.presentation() ?? cardLayer).frame
      let animationCount = cardLayer.animationKeys()?.count ?? 0
      var text = "Card on screen: \(Self.describe(shownFrame))\nModel: \(Self.describe(cardLayer.frame)), animations: \(animationCount)"
      if let drift = dropShadowDrift(cardFrame: shownFrame) {
        text += "\nDrop shadow path off the card by \(String(format: "%.1f", drift)) pt"
      }
      return text
    }

    /// The largest distance between the edges of the drop shadow's path on screen and the card on screen.
    private func dropShadowDrift(cardFrame: CGRect) -> CGFloat? {
      guard let shadowLayer = Self.firstLayer(ofType: DropShadowLayer.self, in: Self.layer(of: stageView)) else {
        return nil
      }
      let shownShadowLayer = shadowLayer.presentation() ?? shadowLayer
      guard let pathBounds = shownShadowLayer.shadowPath?.boundingBoxOfPath else {
        return nil
      }
      let shadowFrame = shownShadowLayer.frame.standardized
      let pathFrame = pathBounds.offsetBy(dx: shadowFrame.minX, dy: shadowFrame.minY)
      let cardFrame = cardFrame.standardized
      return max(
        abs(pathFrame.minX - cardFrame.minX),
        abs(pathFrame.maxX - cardFrame.maxX),
        abs(pathFrame.minY - cardFrame.minY),
        abs(pathFrame.maxY - cardFrame.maxY)
      )
    }

    // MARK: - Helpers

    private static func cardPath(size: CGSize) -> CGPath {
      CGPath(
        roundedRect: CGRect(origin: .zero, size: size),
        cornerWidth: Constants.cornerRadius,
        cornerHeight: Constants.cornerRadius,
        transform: nil
      )
    }

    private static func describe(_ rect: CGRect) -> String {
      String(format: "x %.1f, y %.1f, %.1f x %.1f", rect.minX, rect.minY, rect.width, rect.height)
    }

    private static func firstLayer<T: CALayer>(ofType type: T.Type, in layer: CALayer) -> T? {
      if let match = layer as? T {
        return match
      }
      for sublayer in layer.sublayers ?? [] {
        if let match = firstLayer(ofType: type, in: sublayer) {
          return match
        }
      }
      return nil
    }

    /// Removes the animations of the layer, its sublayers and their masks.
    private static func removeAllAnimations(in layer: CALayer) {
      layer.removeAllAnimations()
      if let mask = layer.mask {
        removeAllAnimations(in: mask)
      }
      for sublayer in layer.sublayers ?? [] {
        removeAllAnimations(in: sublayer)
      }
    }

    private static func layer(of view: View) -> CALayer {
      #if canImport(AppKit)
      return view.layer! // swiftlint:disable:this force_unwrapping
      #else
      return view.layer
      #endif
    }

    // MARK: - Constants

    private enum Constants {

      /// The height of the stage the card moves in.
      static let stageHeight: CGFloat = 220

      /// The card's left edge in the stage, which leaves room for its shadow.
      static let cardLeft: CGFloat = 24

      /// The card's top edge in the stage, and where Move down moves it.
      static let cardTop: CGFloat = 24
      static let movedCardTop: CGFloat = 112

      /// The card's height, and the height Taller now sets.
      static let cardHeight: CGFloat = 60
      static let tallCardHeight: CGFloat = 90

      /// The card's width at the start, after Grow, and after Shrink now. Shrinking halfway through the growth changes
      /// the width by more than the growth has left, which is the case a jump shows the most.
      static let startWidth: CGFloat = 120
      static let grownWidth: CGFloat = 300
      static let shrunkWidth: CGFloat = 30

      /// The card's corner radius, also used for the shadow paths.
      static let cornerRadius: CGFloat = 12

      /// The animated changes' timings, slow enough to change the frame while it animates.
      static let linearTiming: AnimationTiming = .linear(duration: 4)
      static let springTiming: AnimationTiming = .spring(dampingRatio: 0.5, response: 1.6)

      /// Live resize changes the width by this much on every tick, for this many ticks.
      static let liveResizeStep: CGFloat = 18
      static let liveResizeTickCount = 10
      static let liveResizeInterval: TimeInterval = 0.05

      /// How often the readout samples the card.
      static let sampleInterval: TimeInterval = 0.05
    }
  }
}
