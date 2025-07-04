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

  private lazy var maskLayer = CAShapeLayer()

  override init() {
    super.init()

    #if canImport(AppKit)
    contentsScale = NSScreen.main?.backingScaleFactor ?? Constants.defaultScaleFactor
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

  override init(layer: Any) {
    guard let layer = layer as? InnerShadowLayer else {
      // swiftlint:disable:next fatal_error
      fatalError("expect the `layer` to be the same type during an animation.")
    }

    super.init(layer: layer)
  }

  /// Update the inner shadow layer with a new shadow.
  ///
  /// The inner shadow is rendered by a drop shadow from a "punch hole":
  /// The `holePath` is the "punch hole" path.
  /// The `clipPath` is the path that is bigger than the "punch hole" path to clip the shadow.
  ///
  /// By separating the "punch hole" and the "clip path", we can achieve an inner shadow with "spread" effect:
  /// - For a shadow without "spread" effect, the `holePath` and `clipPath` are the same.
  /// - For a shadow with "spread" effect, the `clipPath` is bigger than the `holePath`.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - opacity: The opacity of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - holePath: The path of the "punch hole".
  ///   - clipPath: The path to clip the shadow. If `nil`, the shadow will be clipped by the `holePath`.
  ///   - animationTiming: The animation timing applied to the shadow change. Default to `nil`.
  public func update(color: Color,
                     opacity: CGFloat,
                     radius: CGFloat,
                     offset: CGSize,
                     holePath: @escaping (InnerShadowLayer) -> CGPath,
                     clipPath: ((InnerShadowLayer) -> CGPath)?,
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

    let holePath = holePath(self)
    let clipPath = clipPath?(self) ?? holePath
    let innerShadowPath = innerShadowPath(holePath: holePath, clipPath: clipPath, radius: radius, offset: offset)

    if let animationTiming {
      maskLayer.animateFrame(to: bounds, timing: animationTiming)
      maskLayer.animate(
        keyPath: "path",
        timing: animationTiming,
        from: { ($0.presentation() as? CAShapeLayer).assertNotNil()?.path },
        to: { _ in clipPath }
      )

      animate(
        keyPath: "shadowColor",
        timing: animationTiming,
        from: { $0.presentation()?.shadowColor },
        to: { _ in color }
      )
      animate(keyPath: "shadowOpacity", to: opacity, timing: animationTiming)
      animate(keyPath: "shadowRadius", to: radius, timing: animationTiming)
      animate(keyPath: "shadowOffset", to: offset, timing: animationTiming)
      animate(
        keyPath: "shadowPath",
        timing: animationTiming,
        from: { $0.presentation()?.shadowPath },
        to: { _ in innerShadowPath }
      )
    } else {
      maskLayer.disableActions(for: "position", "bounds", "path") {
        maskLayer.frame = bounds
        maskLayer.path = clipPath
      }

      disableActions(for: "shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath") {
        shadowColor = color
        shadowOpacity = opacity
        shadowRadius = radius
        shadowOffset = offset
        shadowPath = innerShadowPath
      }
    }
  }

  private func innerShadowPath(holePath: CGPath, clipPath: CGPath, radius: CGFloat, offset: CGSize) -> CGPath {
    // make a bigger rect to contain the shadow
    let hExtraSize = radius + abs(offset.width) + 20
    let vExtraSize = radius + abs(offset.height) + 20
    let biggerBounds = clipPath.boundingBoxOfPath.insetBy(dx: -hExtraSize, dy: -vExtraSize)
    let biggerPath = BezierPath(rect: biggerBounds)

    // then cut the shadow path from the bigger rect
    let shadowPath = BezierPath(cgPath: holePath)
    biggerPath.append(shadowPath.reversing())
    return biggerPath.cgPath
  }
}
