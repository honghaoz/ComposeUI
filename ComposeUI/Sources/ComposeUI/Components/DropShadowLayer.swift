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

  /// The size the paths were last evaluated at, to tell a change of a path's shape from a change of the size.
  private var lastPathsSize: CGSize?

  /// Update the drop shadow layer with a new shadow.
  ///
  /// While the layer's frame animates, the paths follow the size it renders: the providers are called with the sizes
  /// it passes through.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - opacity: The opacity of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - path: The path of the shadow, for the layer's size.
  ///   - cutoutPath: The path of the cutout, for the layer's size. If provided, the shadow will be clipped for the
  ///     cutout path. Default to `nil`.
  ///   - animationTiming: The animation timing applied to the shadow change. Only the properties that changed are
  ///     animated, from the state the layer currently shows. `nil` starts no animation and continues the in-flight
  ///     ones toward the new values, landing when they would have. Default to `nil`.
  public func update(color: Color,
                     opacity: CGFloat,
                     radius: CGFloat,
                     offset: CGSize,
                     path: (CGSize) -> CGPath,
                     cutoutPath: ((CGSize) -> CGPath)? = nil,
                     animationTiming: AnimationTiming? = nil)
  {
    updateShadow(color: color.cgColor, opacity: Float(opacity), radius: radius, offset: offset, animationTiming: animationTiming)

    let sizeAnimations = inFlightSizeAnimations()
    updatePath(
      keyPath: "shadowPath",
      from: shadowPath,
      madeFor: lastPathsSize,
      to: path(bounds.size),
      followingSizeAnimations: sizeAnimations,
      animationTiming: animationTiming,
      path: path
    )

    if let cutoutPath {
      updateMaskLayer(
        cutoutPath: cutoutPath,
        radius: radius,
        offset: offset,
        sizeAnimations: sizeAnimations,
        animationTiming: animationTiming
      )
    } else {
      // no cutout: clear any mask a previous update installed, so the rendered state always matches the inputs.
      clearMaskLayer()
    }

    lastPathsSize = bounds.size
  }

  /// Reset the layer so it can be reused as if freshly made.
  func resetForReuse() {
    removeAllAnimations()

    // doesn't clear shadow properties since they are set by `update`
    lastPathsSize = nil

    clearMaskLayer()
  }

  private func updateMaskLayer(cutoutPath: (CGSize) -> CGPath,
                               radius: CGFloat,
                               offset: CGSize,
                               sizeAnimations: InFlightSizeAnimations?,
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

    if let animationTiming {
      if !maskLayer.hasFrame(bounds) {
        maskLayer.animateFrame(to: bounds, timing: animationTiming)
      }
    } else {
      // the mask's frame animations mirror the layer's own, which the render pass leaves as they are on a non-animated
      // frame update, so they are left as they are too instead of being retargeted, and the mask stays aligned
      maskLayer.disableActions(for: "position", "bounds") {
        maskLayer.frame = bounds
      }
    }

    // the mask path is derived from the layer's size like the shadow path, and follows the frame the same way
    maskLayer.updatePath(
      keyPath: "path",
      from: maskLayer.path,
      madeFor: lastPathsSize,
      to: maskLayerPath(cutoutPath: cutoutPath(bounds.size), radius: radius, offset: offset),
      followingSizeAnimations: sizeAnimations,
      animationTiming: animationTiming,
      path: { maskLayerPath(cutoutPath: cutoutPath($0), radius: radius, offset: offset) }
    )
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
