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

/// A model contains the shadow path and clip path for an inner shadow.
public struct InnerShadowPaths {

  /// The shadow path.
  ///
  /// The inner shadow is rendered by a drop shadow from a "punch hole".
  /// This is the "punch hole" path.
  ///
  /// - For inner shadow without "spread" effect, the shadow path is the same as the clip path.
  /// - For inner shadow with "spread" effect, the shadow path is the "punch hole" path, which is smaller than the clip path.
  public let shadowPath: CGPath

  /// The clip path.
  ///
  /// The clip path is the path that encloses the "punch hole" path to clip the shadow.
  /// Generally, the clip path is the shape of the object that the shadow is applied to.
  ///
  /// - For inner shadow without "spread" effect, the clip path is the same as the shadow path.
  /// - For inner shadow with "spread" effect, the clip path is bigger than the shadow path.
  public let clipPath: CGPath?

  /// Initialize a shadow paths model.
  ///
  /// - Parameters:
  ///   - shadowPath: The shadow path.
  ///   - clipPath: The clip path. If `nil`, the shadow will be clipped by the `shadowPath`.
  public init(shadowPath: CGPath, clipPath: CGPath?) {
    self.shadowPath = shadowPath
    self.clipPath = clipPath
  }
}

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
  /// The inner shadow is rendered by a drop shadow from a "punch hole", the paths' shadow path, clipped by the paths'
  /// clip path, see `InnerShadowPaths`.
  ///
  /// While the layer's frame animates, the paths follow the size it renders: `paths` is called with the sizes it passes
  /// through.
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
                     paths: (CGSize) -> InnerShadowPaths,
                     animationTiming: AnimationTiming? = nil)
  {
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

    updateShadow(color: color.cgColor, opacity: Float(opacity), radius: radius, offset: offset, animationTiming: animationTiming)

    let modelPaths = paths(bounds.size)

    // the paths for the size the current paths were made for, to tell a change of a path's shape from a change of the
    // size, see `CALayer.isShapeChanged(current:previous:)`
    let previousPaths = lastPathsSize.map(paths)

    // while the frame animates, the paths follow the size it renders.
    // the paths for the sampled sizes are made once, when the shadow path or the mask path first follows, and shared by both.
    let sizeAnimations = inFlightSizeAnimations()
    var sampledPaths: [InnerShadowPaths]?
    func pathsForSampledSizes() -> [InnerShadowPaths] {
      if let sampledPaths {
        return sampledPaths
      }
      let paths = sizeAnimations?.sampledSizes().map(paths) ?? []
      sampledPaths = paths
      return paths
    }

    func makeShadowPath(for paths: InnerShadowPaths) -> CGPath {
      innerShadowPath(for: paths, radius: radius, offset: offset, useInvertsShadow: useInvertsShadow)
    }

    updateShadowPath(
      to: makeShadowPath(for: modelPaths),
      followingSizeAnimations: sizeAnimations,
      isShapeChanged: CALayer.isShapeChanged(current: shadowPath, previous: previousPaths.map(makeShadowPath(for:))),
      sampledPaths: { pathsForSampledSizes().map(makeShadowPath(for:)) },
      animationTiming: animationTiming
    )

    maskLayer.updatePath(
      to: modelPaths.clipPath ?? modelPaths.shadowPath,
      followingSizeAnimations: sizeAnimations,
      isShapeChanged: CALayer.isShapeChanged(current: maskLayer.path, previous: previousPaths.map { $0.clipPath ?? $0.shadowPath }),
      sampledPaths: { pathsForSampledSizes().map { $0.clipPath ?? $0.shadowPath } },
      animationTiming: animationTiming
    )

    lastPathsSize = bounds.size
  }

  /// Update the inner shadow layer with a new shadow clipped by its own path, see `update(color:opacity:radius:offset:paths:animationTiming:)`.
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
      paths: { InnerShadowPaths(shadowPath: path($0), clipPath: nil) },
      animationTiming: animationTiming
    )
  }

  /// Reset the layer so it can be reused as if freshly made.
  func resetForReuse() {
    maskLayer.removeAllAnimations()
    removeAllAnimations()

    // doesn't clear shadow properties since they are set by `update`
    lastPathsSize = nil
  }

  private func innerShadowPath(for paths: InnerShadowPaths, radius: CGFloat, offset: CGSize, useInvertsShadow: Bool) -> CGPath {
    if useInvertsShadow {
      return paths.shadowPath
    } else {
      return makeInnerShadowPath(holePath: paths.shadowPath, clipPath: paths.clipPath ?? paths.shadowPath, radius: radius, offset: offset)
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
