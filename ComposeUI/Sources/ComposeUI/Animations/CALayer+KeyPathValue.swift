//
//  CALayer+KeyPathValue.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/27/26.
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

import QuartzCore

extension CALayer {

  func setKeyPathValue(_ keyPath: String, _ value: Any) {
    #if canImport(AppKit)
    // an NSView's frame doesn't follow its layer's geometry: after `layer.position = CGPoint(200, 320)`, `layer.frame`
    // has moved but `backedView.frame` keeps the old origin, while UIKit keeps the two in sync. AppKit also rebuilds
    // the layer's bounds from the view's, which drops a bounds origin set only on the layer. so the view's frame and
    // bounds origin are set from the layer's after the change.
    // the frame comes from the position, bounds size and anchor point, since `frame` is undefined under a transform.
    // AppKit resets the transform and the anchor point whenever the view's geometry changes, so the transform is put
    // back. the anchor point isn't: AppKit would reset it on the view's next geometry change anyway, so transforms
    // pivot with a translation from the actual anchor point instead, see `RenderableTransition.scale`
    // most layers don't back a view, so that is checked before the key path
    if let backedView, Self.isViewGeometryKeyPath(keyPath), CALayer.viewSyncSkippingLayer !== self {
      CATransaction.disableAnimationsIfNeeded {
        let modelTransform = transform

        setModelValue(value, forKeyPath: keyPath)

        let size = bounds.size
        let boundsOrigin = bounds.origin
        backedView.frame = CGRect(
          x: position.x.addingProduct(-anchorPoint.x, size.width),
          y: position.y.addingProduct(-anchorPoint.y, size.height),
          width: size.width,
          height: size.height
        )
        if backedView.bounds.origin != boundsOrigin {
          backedView.setBoundsOrigin(boundsOrigin)
        }
        if !CATransform3DEqualToTransform(transform, modelTransform) {
          transform = modelTransform
        }
      }
      return
    }
    #endif

    if keyPath == "opacity", let backedView {
      guard let newValue = value as? Float else {
        ComposeUI.assertFailure("Expected Float value for \"opacity\" keyPath, got \(type(of: value))")
        return
      }
      CATransaction.disableAnimationsIfNeeded {
        backedView.alpha = CGFloat(newValue)
        opacity = newValue
      }
      ComposeUI.assert(CGFloat(opacity) == backedView.alpha)
      return
    }

    CATransaction.disableAnimationsIfNeeded {
      setModelValue(value, forKeyPath: keyPath)
    }
  }

  #if canImport(AppKit)
  /// The layer whose geometry writes don't sync its backing view, see `skippingViewSync(_:)`.
  private static var viewSyncSkippingLayer: CALayer?
  #endif

  /// Execute the block with `setKeyPathValue(_:_:)` not syncing the layer's AppKit backing view after geometry writes.
  ///
  /// UIKit keeps a view's geometry in sync with its layer's, so there the block just runs.
  ///
  /// - Important: The view stays out of sync with the layer until a later geometry write syncs it, so the caller must
  ///   make one after the block.
  ///
  /// - Parameter work: The block to execute.
  @inline(__always)
  func skippingViewSync(_ work: () -> Void) {
    #if canImport(AppKit)
    // only a layer that backs a view is recorded, so the shared state is only accessed on the main thread, where AppKit
    // confines views
    guard backedView != nil else {
      work()
      return
    }

    let outerLayer = CALayer.viewSyncSkippingLayer
    CALayer.viewSyncSkippingLayer = self
    work()
    CALayer.viewSyncSkippingLayer = outerLayer
    #else
    work()
    #endif
  }

  // A write through KVC resolves the key path and boxes a number or a structure in an `NSNumber` or `NSValue`, which
  // costs a sizable share of setting up an animation, so the properties the framework animates are set directly.

  /// Set the layer's model value at a key path.
  ///
  /// - Parameters:
  ///   - value: The value to set.
  ///   - keyPath: The key path to set.
  private func setModelValue(_ value: Any, forKeyPath keyPath: String) {
    // a number or a structure is only set directly when it has the property's own type, as other types rely on KVC's
    // conversion of the boxed value, for example setting a `CGFloat` as the `Float` opacity
    switch keyPath {
    case "position":
      if let value = value as? CGPoint {
        position = value
        return
      }
    case "bounds.size":
      if let value = value as? CGSize {
        bounds.size = value
        return
      }
    case "shadowOffset":
      if let value = value as? CGSize {
        shadowOffset = value
        return
      }
    case "opacity":
      if let value = value as? Float {
        opacity = value
        return
      }
    case "shadowOpacity":
      if let value = value as? Float {
        shadowOpacity = value
        return
      }
    case "borderWidth":
      if let value = value as? CGFloat {
        borderWidth = value
        return
      }
    case "cornerRadius":
      if let value = value as? CGFloat {
        cornerRadius = value
        return
      }
    case "shadowRadius":
      if let value = value as? CGFloat {
        shadowRadius = value
        return
      }
    case "backgroundColor":
      if let color = Self.color(from: value, forKeyPath: keyPath) {
        backgroundColor = color
      }
      return
    case "borderColor":
      if let color = Self.color(from: value, forKeyPath: keyPath) {
        borderColor = color
      }
      return
    case "shadowColor":
      if let color = Self.color(from: value, forKeyPath: keyPath) {
        shadowColor = color
      }
      return
    case "shadowPath":
      if let path = Self.path(from: value, forKeyPath: keyPath) {
        shadowPath = path
      }
      return
    case "path":
      if let shapeLayer = self as? CAShapeLayer {
        if let path = Self.path(from: value, forKeyPath: keyPath) {
          shapeLayer.path = path
        }
        return
      }
    default:
      break
    }
    setValue(value, forKeyPath: keyPath)
  }

  // A conditional cast to a Core Foundation type succeeds for any object, so it can't tell a color or a path from
  // another value, and the functions below check the type ID instead. a `nil` optional bridges to `NSNull`, which KVC
  // sets as is for a color and ignores for a shape layer's path, so the functions return it as a `nil` value to set.
  // Any other value is a mistake, such as a platform color passed for a `CGColor`, which KVC would store as it is, drop,
  // or crash on, so the functions assert on it, and it isn't set.

  /// The value as a color to set at a key path.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - keyPath: The key path of the color.
  /// - Returns: The color, `.some(nil)` for `nil`, or `nil` for a value of another type, which asserts.
  private static func color(from value: Any, forKeyPath keyPath: String) -> CGColor?? {
    let object = value as AnyObject
    switch CFGetTypeID(object) {
    case CGColor.typeID:
      return unsafeDowncast(object, to: CGColor.self)
    case CFNullGetTypeID():
      return .some(nil)
    default:
      ComposeUI.assertFailure("expected a CGColor or nil at \"\(keyPath)\", got \(value)")
      return nil
    }
  }

  /// The value as a path to set at a key path.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - keyPath: The key path of the path.
  /// - Returns: The path, `.some(nil)` for `nil`, or `nil` for a value of another type, which asserts.
  private static func path(from value: Any, forKeyPath keyPath: String) -> CGPath?? {
    let object = value as AnyObject
    switch CFGetTypeID(object) {
    case CGPath.typeID:
      return unsafeDowncast(object, to: CGPath.self)
    case CFNullGetTypeID():
      return .some(nil)
    default:
      ComposeUI.assertFailure("expected a CGPath or nil at \"\(keyPath)\", got \(value)")
      return nil
    }
  }

  #if canImport(AppKit)
  /// Whether a key path is a layer property a view's frame or bounds is derived from, whole or by component, such as
  /// `position` or `bounds.size.width`.
  private static func isViewGeometryKeyPath(_ keyPath: String) -> Bool {
    isKeyPath(keyPath, ofProperty: "position") || isKeyPath(keyPath, ofProperty: "bounds") || isKeyPath(keyPath, ofProperty: "anchorPoint")
  }

  /// Whether a key path is a property or one of its components, such as `bounds.size` of `bounds`, and not a longer
  /// name, such as `anchorPointZ` of `anchorPoint`.
  ///
  /// The key path's prefix and the byte after it are checked instead of its first component split off by character,
  /// since splitting by character segments grapheme clusters, which costs more than the write the check is for.
  private static func isKeyPath(_ keyPath: String, ofProperty property: String) -> Bool {
    keyPath.hasPrefix(property) && (keyPath.utf8.count == property.utf8.count || keyPath.utf8.dropFirst(property.utf8.count).first == UInt8(ascii: "."))
  }
  #endif
}
