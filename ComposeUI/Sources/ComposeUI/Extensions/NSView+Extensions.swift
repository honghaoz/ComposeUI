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
  ///
  /// This method also moves the view's backing layer to the front of its siblings.
  ///
  /// - Parameter view: The subview to move to the front.
  func bringSubviewToFront(_ view: NSView) {
    guard view.superview === self else {
      ComposeUI.assertFailure("view: \(view) is not a subview")
      return
    }

    addSubview(view, positioned: .above, relativeTo: nil)

    // move the layer immediately to match UIKit's `bringSubviewToFront`, which updates the layer order synchronously.
    if let parentLayer = layer, let viewLayer = view.layer {
      parentLayer.bringSublayerToFront(viewLayer)
    }
  }

  /// Sorts the subviews by the given target order in a single sort pass.
  ///
  /// - Note: This method does not update the subviews' backing layers order immediately. AppKit re-syncs the backing
  ///   layers to the subview order at the next display pass, and that re-sync places all backing layers above the
  ///   non-backing sublayers (e.g. manually added sublayers). If the parent layer interleaves manually managed
  ///   sublayers with the subviews' backing layers, fix the backing layers order right after sorting so that the
  ///   display pass re-sync is a no-op.
  ///
  /// - Parameter order: The target order of the subviews, keyed by the subview's object identifier, with smaller values
  ///   ordered lower (behind). Subviews not in the order keep their relative order. Provide a complete order for the
  ///   subviews to reorder: subviews in the order map may not be reordered relative to each other if they are separated
  ///   by subviews not in the map.
  internal func sortSubviews(by order: [ObjectIdentifier: Int]) {
    var order = order
    withUnsafeMutablePointer(to: &order) { orderPointer in
      sortSubviews({ viewA, viewB, rawPointer in
        guard let order = rawPointer?.load(as: [ObjectIdentifier: Int].self) else {
          return ComparisonResult.orderedSame
        }
        guard let indexA = order[ObjectIdentifier(viewA)], let indexB = order[ObjectIdentifier(viewB)] else {
          return ComparisonResult.orderedSame // their ordering isn’t important
        }
        if indexA < indexB {
          return ComparisonResult.orderedAscending
        } else if indexA > indexB {
          return ComparisonResult.orderedDescending
        } else {
          return ComparisonResult.orderedSame
        }
      }, context: orderPointer)
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
