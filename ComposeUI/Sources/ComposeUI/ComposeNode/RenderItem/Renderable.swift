//
//  Renderable.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/19/24.
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

/// A renderable that is either a view or a layer.
public enum Renderable {

  case view(View)
  case layer(CALayer)

  /// The view if the renderable is a view.
  public var view: View? {
    switch self {
    case .view(let view):
      return view
    case .layer:
      return nil
    }
  }

  /// The layer of the renderable.
  public var layer: CALayer {
    switch self {
    case .view(let view):
      return view.layer()
    case .layer(let layer):
      return layer
    }
  }

  /// The bounds of the renderable.
  public var bounds: CGRect {
    switch self {
    case .view(let view):
      return view.bounds
    case .layer(let layer):
      return layer.bounds
    }
  }

  /// The frame of the renderable, where its position and bounds size place it, before its transform applies.
  public var frame: CGRect {
    switch self {
    case .view(let view):
      #if canImport(AppKit)
      // an AppKit view keeps a frame of its own, which its layer's transform doesn't change
      return view.frame
      #else
      // a UIKit view's frame is its layer's, which is undefined under a non-identity transform
      let layer = view.layer
      return CATransform3DIsIdentity(layer.transform) ? view.frame : layer.untransformedFrame
      #endif
    case .layer(let layer):
      return CATransform3DIsIdentity(layer.transform) ? layer.frame : layer.untransformedFrame
    }
  }

  /// Set the frame of the renderable, where its position and bounds size place it, keeping its transform.
  ///
  /// - Parameter frame: The frame to set.
  public func setFrame(_ frame: CGRect) {
    let layer = self.layer
    let transform = layer.transform
    guard !CATransform3DIsIdentity(transform) else {
      setUntransformedFrame(frame)
      return
    }

    // setting `frame` under a non-identity transform fits the transformed bounds into the frame, and AppKit resets a
    // view's layer transform when the view moves or resizes, so the frame is set at identity and the transform is put
    // back. setting `frame` instead of the position and bounds keeps the subclass overrides of the `frame` setter.
    layer.disableActions(for: "transform") {
      layer.transform = CATransform3DIdentity
      setUntransformedFrame(frame)
      layer.transform = transform
    }
  }

  private func setUntransformedFrame(_ frame: CGRect) {
    switch self {
    case .view(let view):
      view.frame = frame
    case .layer(let layer):
      layer.frame = frame
    }
  }

  /// Performs the block, keeping the transform that it leaves through AppKit's resets.
  ///
  /// - Parameter block: The block to perform, which can change the transform, to identity too.
  @inline(__always)
  func performWithTransformKeeping(_ block: () -> Void) {
    #if canImport(AppKit)
    switch self {
    case .view(let view):
      let layer = view.layer()
      let mayBeKeeping = layer.pauseKeepingTransform()
      block()
      layer.resumeKeepingTransform(mayBeKeeping: mayBeKeeping)
    case .layer:
      // AppKit resets only a view's layer transform, so a layer keeps none
      block()
    }
    #else
    block()
    #endif
  }

  /// Whether every copy of the renderable's geometry already matches the frame, within `Constants.geometryTolerance`.
  ///
  /// - Parameter frame: The frame to compare with.
  /// - Returns: `true` if the renderable is already at the frame.
  func hasFrame(_ frame: CGRect) -> Bool {
    switch self {
    case .view(let view):
      #if canImport(AppKit)
      // an AppKit view stores its own frame, which follows the layer only through `CALayer.setKeyPathValue`, so the
      // view must agree too, otherwise a view left behind by a direct layer write would never be re-synced. the
      // tolerance covers AppKit's own arithmetic, which derives the layer geometry from the view's frame exactly on
      // the 1x and 2x pixel grids but not on a third-pixel grid.
      // a UIKit view's frame is the layer's, so comparing it would be redundant.
      let viewFrame = view.frame
      let tolerance = Constants.geometryTolerance
      guard viewFrame.origin.x.isApproximatelyEqual(to: frame.origin.x, absoluteTolerance: tolerance),
            viewFrame.origin.y.isApproximatelyEqual(to: frame.origin.y, absoluteTolerance: tolerance),
            viewFrame.width.isApproximatelyEqual(to: frame.width, absoluteTolerance: tolerance),
            viewFrame.height.isApproximatelyEqual(to: frame.height, absoluteTolerance: tolerance)
      else {
        return false
      }
      #endif
      return view.layer().hasFrame(frame)
    case .layer(let layer):
      return layer.hasFrame(frame)
    }
  }

  /// Applies the frame unless the renderable already has it, animating the change with the timing if given. Without a
  /// timing, the frame animations in flight glide to the new frame, see `CALayer.retargetFrame(to:)`.
  ///
  /// - Parameters:
  ///   - frame: The frame to apply.
  ///   - animationTiming: The timing to animate the change with, or `nil` to apply it without starting an animation.
  func updateFrame(_ frame: CGRect, animationTiming: AnimationTiming?) {
    // re-applying an unchanged frame is wasteful: without a timing it dirties the renderable and on AppKit posts a
    // frame-change notification that forces a layout pass, with a timing it adds zero-delta animations that live for
    // the timing's duration and pile up under repeated passes.
    guard !hasFrame(frame) else {
      return
    }

    // the layer is animated only when it moves. when it already has the frame and only an AppKit view's own frame
    // copy is out of sync, setting the frame re-syncs the copy without adding zero-delta animations, and a retarget
    // finds no change to glide. a layer usually has no animations, and then its frame is set directly.
    let layer = self.layer
    if let animationTiming {
      if !layer.hasFrame(frame) {
        layer.animateFrame(to: frame, timing: animationTiming)
        return
      }
    } else if let animationKeys = layer.unbridgedAnimationKeys {
      layer.retargetFrame(to: frame, animationKeys: animationKeys)
      return
    }
    setFrame(frame)
  }

  /// Add the renderable as a sublayer to the parent view.
  ///
  /// - Parameter parent: The parent view.
  public func addToParent(_ parent: View) {
    switch self {
    case .view(let view):
      #if canImport(AppKit)
      if view.superview !== parent {
        parent.addSubview(view)
      } else {
        // the view is in the parent already, where a removal left it, and seldom at the front, so it moves there without
        // checking `subviews.last` first, since reading `subviews` copies the array
        parent.bringSubviewToFront(view)
      }
      #endif

      #if canImport(UIKit)
      // `addSubview` moves a view that's in the parent already to the front, as `bringSubviewToFront` does. its cost
      // grows with the view's subviews, which it walks without calling their window callbacks, while
      // `bringSubviewToFront` sets the parent layer's whole sublayers array again, which allocates, and costs more for
      // a view with few subviews, as the views that a render pass reuses mostly are
      parent.addSubview(view)
      #endif
    case .layer(let layer):
      let parentLayer = parent.layer()
      if layer.superlayer !== parentLayer {
        parentLayer.addSublayer(layer)
      } else if parentLayer.sublayers?.last !== layer {
        // moving a layer that's at the front already costs the next commit more than reading `sublayers`
        parentLayer.bringSublayerToFront(layer)
      }
    }
  }

  /// Remove the renderable from its parent.
  public func removeFromParent() {
    switch self {
    case .view(let view):
      view.removeFromSuperview()
    case .layer(let layer):
      layer.removeFromSuperlayer()
    }
  }

  /// Move the renderable to the front of its siblings.
  public func moveToFront() {
    switch self {
    case .view(let view):
      if let superview = view.superview, superview.subviews.last !== view {
        superview.bringSubviewToFront(view)
      }
    case .layer(let layer):
      // moving a layer that's at the front already costs the next commit more than reading `sublayers`
      if let superlayer = layer.superlayer, superlayer.sublayers?.last !== layer {
        superlayer.bringSublayerToFront(layer)
      }
    }
  }
}
