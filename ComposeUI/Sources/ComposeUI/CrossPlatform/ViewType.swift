//
//  ViewType.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/27/24.
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

/// A type that represents a view.
public protocol ViewType: View {}

extension View: ViewType {}

/// A type that represents a cross-platform view.
protocol _ViewType: View {

  /// Get the backing `CALayer` of the view.
  func layer() -> CALayer

  /// The content scale factor.
  var contentScaleFactor: CGFloat { get set }

  /// The attaching screen's scale factor.
  var screenScaleFactor: CGFloat { get }
}

extension View: _ViewType {}

extension _ViewType {

  func layer() -> CALayer {
    #if canImport(AppKit)
    guard let layer else {
      assertionFailure("NSView should be layer backed. Please set `wantsLayer == true`.")
      wantsLayer = true
      return self.layer!
    }
    return layer
    #else
    return layer
    #endif
  }

  #if canImport(AppKit)
  var contentScaleFactor: CGFloat {
    get {
      layer().contentsScale
    }
    set {
      layer().contentsScale = newValue
    }
  }
  #endif

  var screenScaleFactor: CGFloat {
    if let window {
      #if os(macOS)
      return window.backingScaleFactor
      #elseif os(visionOS)
      // visionOS doesn't support fixed scale factor.
      // just use 2.0 as a default value.
      return 2
      #else
      return window.screen.scale
      #endif
    } else {
      #if os(macOS)
      return NSScreen.main?.backingScaleFactor ?? 2.0
      #else
      return UIScreen.main.scale
      #endif
    }
  }
}
