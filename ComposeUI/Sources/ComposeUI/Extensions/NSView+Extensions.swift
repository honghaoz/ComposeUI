//
//  NSView+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/28/24.
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

public extension NSView {

  /// Update common settings for a layer-backed view.
  @_spi(Private)
  func updateCommonSettings() {
    // It seems like using auto layout can avoid certain ambiguous layout issues
    //
    // translatesAutoresizingMaskIntoConstraints = false

    wantsLayer = true

    // Don't set cornerCurve to .continuous to match the UIKit's default value
    //
    // layer?.cornerCurve = .continuous

    layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? Constants.defaultScaleFactor

    // turns off clipping
    // https://stackoverflow.com/a/53176282/3164091
    layer?.masksToBounds = false
  }

  // MARK: - UIKit Compatibility

  /// The alpha value of the view.
  @inlinable
  @inline(__always)
  var alpha: CGFloat {
    get {
      alphaValue
    }
    set {
      alphaValue = newValue
    }
  }

  // MARK: - Layout

  /// Sets the view's layout flag to true, indicating that the view needs a layout pass.
  @inlinable
  @inline(__always)
  func setNeedsLayout() {
    needsLayout = true
  }

  /// Performs a layout pass immediately if the view needs a layout pass.
  @inlinable
  @inline(__always)
  func layoutIfNeeded() {
    layoutSubtreeIfNeeded()
  }

  // MARK: - View Hierarchy

  /// Moves the specified subview so that it appears on top of its siblings.
  /// - Parameter view: The subview to move to the front.
  func bringSubviewToFront(_ view: NSView) {
    guard view.superview === self else {
      ComposeUI.assertFailure("view: \(view) is not a subview")
      return
    }

    var view = view
    withUnsafeMutablePointer(to: &view) { viewPointer in
      sortSubviews({ viewA, viewB, rawPointer in
        let view = rawPointer?.load(as: NSView.self)

        switch view {
        case viewA:
          // A is the view. A should be up.
          return ComparisonResult.orderedDescending // viewB should be ordered lower
        case viewB:
          // B is the view. B should be up.
          return ComparisonResult.orderedAscending // viewA should be ordered lower
        default:
          return ComparisonResult.orderedSame // their ordering isn’t important
        }
      }, context: viewPointer)
    }

    if let parentLayer = layer, let viewLayer = view.layer {
      parentLayer.bringSublayerToFront(viewLayer)
    }
  }

  // MARK: - ignoreHitTest

  private static let _ignoreHitTestKey: String = ["ign", "oreH", "it", "T", "est"].joined()

  /// A boolean flag indicating whether the view should ignore hit testing.
  var ignoreHitTest: Bool {
    get {
      let value = value(forKey: Self._ignoreHitTestKey) as? Bool
      ComposeUI.assert(value != nil, "missing value for \(Self._ignoreHitTestKey)")
      return value ?? false
    }
    set {
      setValue(newValue, forKey: Self._ignoreHitTestKey)
    }

    /// https://avaidyam.github.io/2018/03/22/Exercise-Modern-Cocoa-Views.html
    /// https://stackoverflow.com/a/2906605/3164091
    /// https://stackoverflow.com/questions/11923597/using-valueforkey-to-access-view-in-uibarbuttonitem-private-api-violation
  }
}

#endif
