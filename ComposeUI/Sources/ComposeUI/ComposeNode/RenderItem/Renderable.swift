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
      parent.addSubview(view)
    case .layer(let layer):
      parent.layer().addSublayer(layer)
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
      view.superview?.bringSubviewToFront(view)
    case .layer(let layer):
      layer.superlayer?.bringSublayerToFront(layer)
    }
  }
}
