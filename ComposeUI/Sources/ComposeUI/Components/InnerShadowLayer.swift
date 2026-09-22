//
//  InnerShadowLayer.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/5/25.
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

import QuartzCore

/// A layer that renders an inner shadow.
open class InnerShadowLayer: CALayer {

  #if DEBUG
  private var supportsInvertsShadowOverride: Bool?
  #endif

  private lazy var maskLayer = CAShapeLayer()

  override public init() {
    super.init()

    #if canImport(AppKit)
    contentsScale = NSScreen.main?.backingScaleFactor ?? ComposeUI.Constants.defaultScaleFactor
    #endif

    #if canImport(UIKit)
    #if os(visionOS)
    contentsScale = Constants.defaultScaleFactor
    wantsDynamicContentScaling = true
    #else
    contentsScale = UIScreen.main.scale
    #endif
    #endif
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override public init(layer: Any) {
    guard let layer = layer as? InnerShadowLayer else {
      // swiftlint:disable:next fatal_error
      fatalError("expect the `layer` to be the same type during an animation.")
    }

    #if DEBUG
    supportsInvertsShadowOverride = layer.supportsInvertsShadowOverride
    #endif

    super.init(layer: layer)
  }

  /// The size the paths were last evaluated at, to tell a change of a path's shape from a change of the size.
  private var lastPathsSize: CGSize?

  /// Update the inner shadow layer with a new shadow.
  ///
  /// The inner shadow is rendered by a drop shadow from a "punch hole":
  /// The `holePath` is the "punch hole" path.
  /// The `clipPath` is the path that encloses the "punch hole" path to clip the shadow.
  ///
  /// By separating the "punch hole" and the "clip path", we can achieve an inner shadow with "spread" effect:
  /// - For a shadow without "spread" effect, the `holePath` and `clipPath` are the same.
  /// - For a shadow with "spread" effect, the `clipPath` is bigger than the `holePath`.
  ///
  /// While the layer's frame animates, the paths follow the size it renders: the providers are called with the sizes
  /// it passes through.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - opacity: The opacity of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - holePath: The path of the "punch hole", for the layer's size.
  ///   - clipPath: The path to clip the shadow, for the layer's size. If `nil`, the shadow will be clipped by the `holePath`.
  ///   - animationTiming: The animation timing applied to the shadow change. Only the properties that changed are
  ///     animated, from the state the layer currently shows. `nil` starts no animation and continues the in-flight
  ///     ones toward the new values, landing when they would have. Default to `nil`.
  public func update(color: Color,
                     opacity: CGFloat,
                     radius: CGFloat,
                     offset: CGSize,
                     holePath: (CGSize) -> CGPath,
                     clipPath: ((CGSize) -> CGPath)?,
                     animationTiming: AnimationTiming? = nil)
  {
    let color = color.cgColor
    let opacity = Float(opacity)

    // initialize mask layer if not initialized
    if mask !== maskLayer {
      mask = maskLayer
      maskLayer.disableActions(for: "position", "bounds") {
        maskLayer.frame = bounds
      }
    }

    #if DEBUG
    let useInvertsShadow: Bool = self.supportsInvertsShadowOverride ?? self.supportsInvertsShadow
    #else
    let useInvertsShadow: Bool = self.supportsInvertsShadow
    #endif
    if useInvertsShadow {
      self.disableActions {
        if !self.invertsShadow {
          self.invertsShadow = true // use the invertsShadow API
        }
      }
    }

    if let animationTiming {
      // only the properties whose model value differs from the target are animated: an unchanged additive one would
      // add a zero-delta animation that lives for the timing's duration and piles up on repeated passes, and an
      // unchanged non-additive one would replace an in-flight animation to the same target and restart its easing.
      if !maskLayer.hasFrame(bounds) {
        maskLayer.animateFrame(to: bounds, timing: animationTiming)
      }

      if shadowColor != color {
        animate(
          keyPath: "shadowColor",
          timing: animationTiming,
          from: { $0.presentation()?.shadowColor },
          to: { _ in color }
        )
      }
      if shadowOpacity != opacity {
        // the render server clamps the opacity for each animation, so additive animations wouldn't compose correctly,
        // so use non-additive animation instead
        animate(
          keyPath: "shadowOpacity",
          timing: animationTiming,
          from: { $0.presentation()?.shadowOpacity },
          to: { _ in opacity }
        )
      }
      if shadowRadius != radius {
        animate(keyPath: "shadowRadius", to: radius, timing: animationTiming)
      }
      if shadowOffset != offset {
        animate(keyPath: "shadowOffset", to: offset, timing: animationTiming)
      }
    } else {
      // no animation timing: continue the in-flight motion. the mask's frame animations mirror the layer's own, which
      // the render pass leaves as they are on a non-animated frame update, so they are left as they are too instead of
      // being retargeted, and the mask stays aligned with the layer
      maskLayer.disableActions(for: "position", "bounds") {
        maskLayer.frame = bounds
      }

      retarget(keyPath: "shadowColor", to: color)
      retarget(keyPath: "shadowOpacity", to: opacity)
      retarget(keyPath: "shadowRadius", to: radius)
      retarget(keyPath: "shadowOffset", to: offset)
    }

    let sizeAnimations = inFlightSizeAnimations()
    updatePath(
      keyPath: "shadowPath",
      from: shadowPath,
      madeFor: lastPathsSize,
      to: innerShadowPath(for: bounds.size, holePath: holePath, clipPath: clipPath, radius: radius, offset: offset, useInvertsShadow: useInvertsShadow),
      followingSizeAnimations: sizeAnimations,
      animationTiming: animationTiming,
      path: { innerShadowPath(for: $0, holePath: holePath, clipPath: clipPath, radius: radius, offset: offset, useInvertsShadow: useInvertsShadow) }
    )

    maskLayer.updatePath(
      keyPath: "path",
      from: maskLayer.path,
      madeFor: lastPathsSize,
      to: clipPath?(bounds.size) ?? holePath(bounds.size),
      followingSizeAnimations: sizeAnimations,
      animationTiming: animationTiming,
      path: { clipPath?($0) ?? holePath($0) }
    )

    lastPathsSize = bounds.size
  }

  /// Reset the layer so it can be reused as if freshly made.
  func resetForReuse() {
    maskLayer.removeAllAnimations()
    removeAllAnimations()

    // doesn't clear shadow properties since they are set by `update`
    lastPathsSize = nil
  }

  /// The inner shadow path for a size: the hole for an inverted shadow, the clip's bigger rect punched by the hole otherwise.
  private func innerShadowPath(for size: CGSize,
                               holePath: (CGSize) -> CGPath,
                               clipPath: ((CGSize) -> CGPath)?,
                               radius: CGFloat,
                               offset: CGSize,
                               useInvertsShadow: Bool) -> CGPath
  {
    let holePath = holePath(size)
    if useInvertsShadow {
      return holePath
    } else {
      return makeInnerShadowPath(holePath: holePath, clipPath: clipPath?(size) ?? holePath, radius: radius, offset: offset)
    }
  }

  private func makeInnerShadowPath(holePath: CGPath, clipPath: CGPath, radius: CGFloat, offset: CGSize) -> CGPath {
    // make a bigger rect to contain the shadow.
    // `radius + abs(offset)` covers the shadow's nominal extent, add extra 20pt to ensure the shadow is fully contained.
    let hExtraSize = radius + abs(offset.width) + 20
    let vExtraSize = radius + abs(offset.height) + 20
    let biggerBounds = clipPath.boundingBoxOfPath.insetBy(dx: -hExtraSize, dy: -vExtraSize)
    let biggerPath = BezierPath(rect: biggerBounds)

    // then cut the shadow path from the bigger rect
    let shadowPath = BezierPath(cgPath: holePath)
    biggerPath.append(shadowPath.reversing())
    return biggerPath.cgPath
  }

  // MARK: - Testing

  #if DEBUG

  var test: Test { Test(host: self) }

  class Test {

    private let host: InnerShadowLayer

    fileprivate init(host: InnerShadowLayer) {
      ComposeUI.assert(Thread.isRunningXCTest, "Test namespace should only be used in test target.")
      self.host = host
    }

    var supportsInvertsShadowOverride: Bool? {
      get {
        host.supportsInvertsShadowOverride
      }
      set {
        host.supportsInvertsShadowOverride = newValue
      }
    }
  }

  #endif
}
