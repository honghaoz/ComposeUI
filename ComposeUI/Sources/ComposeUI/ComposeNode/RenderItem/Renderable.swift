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
///
/// The render pass owns the renderable's frame and transform: it resets the transform to identity at the start of the
/// pass, applies the frame after the `willInsert` or `willUpdate` block, and calls the `update` block last. A layer's
/// frame is undefined under a non-identity transform, so the transform must still be identity when the frame is
/// applied: `willInsert` and `willUpdate` must not change it. Set a transform in `update`, it is reset and re-applied
/// on every pass.
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

  /// The frame of the renderable.
  public var frame: CGRect {
    switch self {
    case .view(let view):
      return view.frame
    case .layer(let layer):
      return layer.frame
    }
  }

  /// Set the frame of the renderable.
  ///
  /// - Parameter frame: The frame to set.
  public func setFrame(_ frame: CGRect) {
    switch self {
    case .view(let view):
      view.frame = frame
    case .layer(let layer):
      layer.frame = frame
    }
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

  /// Applies the frame unless the renderable already has it, animating the change with the timing if given.
  ///
  /// - Precondition: The renderable layer's transform must be identity, see `Renderable`.
  ///
  /// - Parameters:
  ///   - frame: The frame to apply.
  ///   - animationTiming: The timing to animate the change with, or `nil` to apply it immediately.
  func updateFrame(_ frame: CGRect, animationTiming: AnimationTiming?) {
    assertIdentityTransform()

    // re-applying an unchanged frame is wasteful: without a timing it dirties the renderable and on AppKit posts a
    // frame-change notification that forces a layout pass, with a timing it adds zero-delta animations that live for
    // the timing's duration and pile up under repeated passes.
    guard !hasFrame(frame) else {
      return
    }

    // the layer is animated only when it moves. when it already has the frame and only an AppKit view's own frame
    // copy is out of sync, setting the frame re-syncs the copy without adding zero-delta animations.
    if let animationTiming, !layer.hasFrame(frame) {
      layer.animateFrame(to: frame, timing: animationTiming)
    } else {
      setFrame(frame)
    }
  }

  /// Asserts, in debug builds, that the renderable's transform is identity, as the render pass requires when it applies
  /// the frame, see `Renderable`.
  func assertIdentityTransform() {
    ComposeUI.assert(CATransform3DIsIdentity(layer.transform), "the renderable's transform must be identity when its frame is applied, set a transform in `update` instead of `willInsert` or `willUpdate`")
  }

  /// Add the renderable as a sublayer to the parent view.
  ///
  /// - Parameter parent: The parent view.
  public func addToParent(_ parent: View) {
    switch self {
    case .view(let view):
      if view.superview !== parent {
        // view is not in the parent, add it.
        //
        // the `view.superview !== parent` guard above skips this when the view is already in the parent.
        // calling `addSubview` redundantly triggers `_didMoveFromWindow:toWindow:`, which recursively
        // traverses the entire subview hierarchy.
        parent.addSubview(view)
      } else if parent.subviews.last !== view {
        // view is already in the parent, but not at the front, bring it to front.
        //
        // the `subviews.last !== view` guard above skips this when the view is already at the front.
        // `bringSubviewToFront` re-inserts the view (and its backing layer) at the front, O(N) per call.
        parent.bringSubviewToFront(view)
      }
    case .layer(let layer):
      let parentLayer = parent.layer()
      if layer.superlayer !== parentLayer {
        parentLayer.addSublayer(layer)
      } else if parentLayer.sublayers?.last !== layer {
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
      if let superlayer = layer.superlayer, superlayer.sublayers?.last !== layer {
        superlayer.bringSublayerToFront(layer)
      }
    }
  }
}
