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

  /// Add the renderable as a sublayer to the parent view.
  ///
  /// - Parameter parent: The parent view.
  public func addToParent(_ parent: View) {
    switch self {
    case .view(let view):
      if view.superview !== parent {
        // view is not in the parent, add it.
        //
        // this avoids calling addSubview which triggers `_didMoveFromWindow:toWindow:`
        // that recursively traverses the entire subview hierarchy.
        parent.addSubview(view)
      } else if parent.subviews.last !== view {
        // view is already in the parent, but not at the front, bring it to front.
        //
        // this avoids bringSubviewToFront which triggers `CA::Layer::set_sublayers`
        // → `update_sublayers` → `qsort`, which is O(N log N) per call. With N views that compounds to O(N² log N).
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
