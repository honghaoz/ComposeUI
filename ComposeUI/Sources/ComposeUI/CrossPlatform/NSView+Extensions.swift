//
//  NSView+Extensions.swift
//  ComposeUI
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

extension NSView {

  /// Update common settings for a layer-backed view.
  func updateCommonSettings() {
    wantsLayer = true

    // don't set cornerCurve to .continuous to match the UIKit's default value
    // layer?.cornerCurve = .continuous

    layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

    // turns off clipping
    layer?.masksToBounds = false
  }

  // MARK: - Layout

  func setNeedsLayout() {
    needsLayout = true
  }

  func layoutIfNeeded() {
    layoutSubtreeIfNeeded()
  }

  // MARK: - View Hierarchy

  /// Moves the specified subview so that it appears on top of its siblings.
  /// - Parameter view: The subview to move to the front.
  func bringSubviewToFront(_ view: NSView) {
    guard view.superview === self else {
      assertionFailure("view: \(view) is not a subview")
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
  }

  // MARK: - ignoreHitTest

  private static let _ignoreHitTestKey: String = ["ignoreH", "it", "T", "est"].joined()

  var ignoreHitTest: Bool {
    get {
      let value = value(forKey: Self._ignoreHitTestKey) as? Bool
      assert(value != nil, "missing value for \(Self._ignoreHitTestKey)")
      return value ?? false
    }
    set {
      setValue(newValue, forKey: Self._ignoreHitTestKey)
    }
  }
}

#endif
