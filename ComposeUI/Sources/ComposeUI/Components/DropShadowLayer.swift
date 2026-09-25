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

/// A model contains the shadow path and cutout path for a drop shadow.
public struct DropShadowPaths {

  /// The shadow path.
  public let shadowPath: CGPath

  /// The cutout path. If provided, the shadow will be clipped for the cutout path.
  public let cutoutPath: CGPath?

  /// Initialize a shadow paths model.
  ///
  /// - Parameters:
  ///   - shadowPath: The shadow path.
  ///   - cutoutPath: The cutout path.
  public init(shadowPath: CGPath, cutoutPath: CGPath?) {
    self.shadowPath = shadowPath
    self.cutoutPath = cutoutPath
  }
}

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
    contentsScale = NSScreen.main?.backingScaleFactor ?? ComposeUI.Constants.defaultScaleFactor
    #endif

    #if canImport(UIKit)
    #if os(visionOS)
    contentsScale = ComposeUI.Constants.defaultScaleFactor
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
  ///   - paths: The paths of the shadow, for the layer's size.
  ///   - animationTiming: The animation timing applied to the shadow change. Only the properties that changed are
  ///     animated, from the state the layer currently shows. `nil` starts no animation and continues the in-flight
  ///     ones toward the new values, landing when they would have. Default to `nil`.
  public func update(color: Color,
                     opacity: CGFloat,
                     radius: CGFloat,
                     offset: CGSize,
                     paths: (CGSize) -> DropShadowPaths,
                     animationTiming: AnimationTiming? = nil)
  {
    let color = color.cgColor
    let opacity = Float(opacity)
    let paths = paths(bounds.size)

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
        // the render server clamps the shadow opacity after each animation, so opposing additive animations wouldn't
        // compose on screen (see `animate(keyPath:to:timing:updateAnimation:)`): the opacity animates non-additively
        // from the shown value, like the color
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
      animatePath(keyPath: "shadowPath", to: paths.shadowPath, timing: animationTiming)
    } else {
      // no animation timing: continue the in-flight motion
      retarget(keyPath: "shadowColor", to: color)
      retarget(keyPath: "shadowOpacity", to: opacity)
      retarget(keyPath: "shadowRadius", to: radius)
      retarget(keyPath: "shadowOffset", to: offset)

      setPath(keyPath: "shadowPath", to: paths.shadowPath)
    }

    if let cutoutPath = paths.cutoutPath {
      updateMaskLayer(cutoutPath: cutoutPath, animationTiming: animationTiming)
    } else {
      // no cutout: clear any mask a previous update installed, so the rendered state always matches the inputs.
      clearMaskLayer()
    }
  }

  /// Update the drop shadow layer with a new shadow without a cutout.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - opacity: The opacity of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - path: The path of the shadow, for the layer's size.
  ///   - animationTiming: The animation timing applied to the shadow change. Default to `nil`.
  public func update(color: Color,
                     opacity: CGFloat,
                     radius: CGFloat,
                     offset: CGSize,
                     path: (CGSize) -> CGPath,
                     animationTiming: AnimationTiming? = nil)
  {
    update(
      color: color,
      opacity: opacity,
      radius: radius,
      offset: offset,
      paths: { DropShadowPaths(shadowPath: path($0), cutoutPath: nil) },
      animationTiming: animationTiming
    )
  }

  /// Reset the layer so it can be reused as if freshly made.
  func resetForReuse() {
    removeAllAnimations()

    // doesn't clear shadow properties since they are set by `update`

    clearMaskLayer()
  }

  private func updateMaskLayer(cutoutPath: CGPath, animationTiming: AnimationTiming?) {
    // initialize mask layer if not initialized
    if mask !== maskLayer {
      mask = maskLayer
      maskLayer.disableActions(for: "position", "bounds") {
        maskLayer.frame = bounds
      }
      maskLayer.fillRule = .evenOdd // to match the clip out path
    }

    let maskPath = maskLayerPath(cutoutPath: cutoutPath)

    if let animationTiming {
      if !maskLayer.hasFrame(bounds) {
        maskLayer.animateFrame(to: bounds, timing: animationTiming)
      }
      maskLayer.animatePath(keyPath: "path", to: maskPath, timing: animationTiming)
    } else {
      // no animation timing: continue the in-flight motion. the mask's frame animations mirror the layer's own, which
      // the render pass leaves as they are on a non-animated frame update, so they are left as they are too instead of
      // being retargeted, and the mask stays aligned with the layer
      maskLayer.disableActions(for: "position", "bounds") {
        maskLayer.frame = bounds
      }
      maskLayer.setPath(keyPath: "path", to: maskPath)
    }
  }

  private func maskLayerPath(cutoutPath: CGPath) -> CGPath {
    ComposeUI.assert(bounds.origin == .zero, "check if boundingBoxOfPath works for non zero origin bounds")
    let biggerBounds = cutoutPath.boundingBoxOfPath.insetBy(dx: -Constants.maskMargin, dy: -Constants.maskMargin)

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

  // MARK: - Constants

  private enum Constants {

    /// How far the mask's rect reaches past the cutout, far beyond any shadow's blur. Core Animation only draws the
    /// mask where the shadow is, so the margin costs nothing.
    static let maskMargin: CGFloat = 1000000
  }
}
