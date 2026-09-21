//
//  DropShadowLayer.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/1/25.
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

/// A layer that renders a drop shadow.
open class DropShadowLayer: CALayer {

  /// The drop shadow layer never clips the content.
  override public final var masksToBounds: Bool {
    get { super.masksToBounds }
    set {} // do nothing
  }

  /// The mask layer to clip the drop shadow out of the main shape.
  private lazy var maskLayer = CAShapeLayer()

  override public init() {
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

    super.masksToBounds = false
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override public init(layer: Any) {
    guard let layer = layer as? DropShadowLayer else {
      // swiftlint:disable:next fatal_error
      fatalError("expect the `layer` to be the same type during an animation.")
    }
    super.init(layer: layer)
  }

  /// Update the drop shadow layer with a new shadow.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - opacity: The opacity of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - path: The path of the shadow.
  ///   - cutoutPath: The path of the cutout. If provided, the shadow will be clipped for the cutout path. Default to `nil`.
  ///   - animationTiming: The animation timing applied to the shadow change. Only the properties that changed are
  ///     animated, from the state the layer currently shows. `nil` starts no animation and continues the in-flight
  ///     ones toward the new values, landing when they would have. Default to `nil`.
  public func update(color: Color,
                     opacity: CGFloat,
                     radius: CGFloat,
                     offset: CGSize,
                     path: (DropShadowLayer) -> CGPath,
                     cutoutPath: ((DropShadowLayer) -> CGPath)? = nil,
                     animationTiming: AnimationTiming? = nil)
  {
    let color = color.cgColor
    let opacity = Float(opacity)

    if let animationTiming {
      // only the properties whose model value differs from the target are animated: an unchanged additive one would
      // add a zero-delta animation that lives for the timing's duration and piles up on repeated passes, and an
      // unchanged non-additive one would replace an in-flight animation to the same target and restart its easing.
      if shadowColor != color {
        animate(
          keyPath: "shadowColor",
          timing: animationTiming,
          from: { $0.presentation()?.shadowColor },
          to: { _ in color }
        )
      }
      if shadowOpacity != opacity {
        animate(keyPath: "shadowOpacity", to: opacity, timing: animationTiming)
      }
      if shadowRadius != radius {
        animate(keyPath: "shadowRadius", to: radius, timing: animationTiming)
      }
      if shadowOffset != offset {
        animate(keyPath: "shadowOffset", to: offset, timing: animationTiming)
      }
      // the path is requested after the other properties are applied, so a provider can derive it from them
      let newShadowPath = path(self)
      if shadowPath != newShadowPath {
        animate(
          keyPath: "shadowPath",
          timing: animationTiming,
          from: { $0.presentation()?.shadowPath },
          to: { _ in newShadowPath }
        )
      }
    } else {
      // no animation timing: continue the in-flight motion
      retarget(keyPath: "shadowColor", to: color)
      disableActions(for: "shadowOpacity", "shadowRadius", "shadowOffset") { // additive properties don't need retarget
        shadowOpacity = opacity
        shadowRadius = radius
        shadowOffset = offset
      }

      // the path is requested after the other properties are applied, so a provider can derive it from them
      retarget(keyPath: "shadowPath", to: path(self))
    }

    if let cutoutPath {
      updateMaskLayer(cutoutPath: cutoutPath, radius: radius, offset: offset, animationTiming: animationTiming)
    } else {
      // no cutout: clear any mask a previous update installed, so the rendered state always matches the inputs.
      clearMaskLayer()
    }
  }

  /// Reset the layer so it can be reused as if freshly made.
  func resetForReuse() {
    removeAllAnimations()

    // doesn't clear shadow properties since they are set by `update`

    clearMaskLayer()
  }

  private func updateMaskLayer(cutoutPath: (DropShadowLayer) -> CGPath,
                               radius: CGFloat,
                               offset: CGSize,
                               animationTiming: AnimationTiming?)
  {
    // initialize mask layer if not initialized
    if mask !== maskLayer {
      mask = maskLayer
      maskLayer.disableActions(for: "position", "bounds") {
        maskLayer.frame = bounds
      }
      maskLayer.fillRule = .evenOdd // to match the clip out path
    }

    let maskPath = maskLayerPath(cutoutPath: cutoutPath(self), radius: radius, offset: offset)

    if let animationTiming {
      if !maskLayer.hasFrame(bounds) {
        maskLayer.animateFrame(to: bounds, timing: animationTiming)
      }
      if maskLayer.path != maskPath {
        maskLayer.animate(
          keyPath: "path",
          timing: animationTiming,
          from: { $0.presentation().assertNotNil()?.path },
          to: { _ in maskPath }
        )
      }
    } else {
      // no animation timing: continue the in-flight motion
      maskLayer.disableActions(for: "position", "bounds") { // additive properties don't need retarget
        maskLayer.frame = bounds
      }
      maskLayer.retarget(keyPath: "path", to: maskPath) // non-additive property needs retarget
    }
  }

  private func maskLayerPath(cutoutPath: CGPath, radius: CGFloat, offset: CGSize) -> CGPath {
    let hExtraSize = radius + abs(offset.width) + 1000
    let vExtraSize = radius + abs(offset.height) + 1000
    ComposeUI.assert(bounds.origin == .zero, "check if boundingBoxOfPath works for non zero origin bounds")
    let biggerBounds = cutoutPath.boundingBoxOfPath.insetBy(dx: -hExtraSize, dy: -vExtraSize)

    let biggerPath = CGMutablePath()
    biggerPath.addPath(CGPath(rect: biggerBounds, transform: nil))
    biggerPath.addPath(cutoutPath)
    return biggerPath
  }

  private func clearMaskLayer() {
    guard mask != nil else {
      return
    }

    mask?.removeAllAnimations()
    disableActions(for: "mask") {
      self.mask = nil
      self.maskLayer.path = nil
    }
  }
}
