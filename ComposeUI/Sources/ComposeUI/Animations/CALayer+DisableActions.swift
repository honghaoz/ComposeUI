//
//  CALayer+DisableActions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/21.
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
import ObjectiveC.runtime

// MARK: - Disable Actions

public extension CALayer {

  /// Execute the block with the specified actions disabled.
  ///
  /// `CALayer` has implicit animations for some properties, which is not desired in some cases.
  /// This method helps to disable the implicit animations for the given keys.
  ///
  /// Example:
  ///
  /// ```swift
  /// layer.disableActions(for: "position", "bounds", "transform") {
  ///   layer.frame = newFrame
  ///   layer.transform = CATransform3DIdentity
  /// }
  /// ```
  ///
  /// If you need to disable all possible actions for the layer, use `disableActions(_:)`.
  /// - Parameters:
  ///   - keys: The keys to disable actions for.
  ///   - work: The block to execute.
  @inlinable
  @inline(__always)
  func disableActions(for keys: String..., work: () throws -> Void) rethrows {
    try disableActions(for: keys, work)
  }

  /// Execute the block with the specified actions disabled.
  ///
  /// `CALayer` has implicit animations for some properties, which is not desired in some cases.
  /// This method helps to disable the implicit animations for the given keys.
  ///
  /// Example:
  ///
  /// ```swift
  /// layer.disableActions(for: ["position", "bounds", "transform"]) {
  ///   layer.frame = newFrame
  ///   layer.transform = CATransform3DIdentity
  /// }
  /// ```
  ///
  /// If you need to disable all possible actions for the layer, use `disableActions(_:)`.
  ///
  /// - Parameters:
  ///   - keys: The keys to disable actions for.
  ///   - work: The block to execute.
  func disableActions(for keys: [String], _ work: () throws -> Void) rethrows {
    let originalActions = actions

    var disabledActions = [String: CAAction]()
    disabledActions.reserveCapacity(keys.count)

    for key in keys {
      disabledActions[key] = NSNull()
    }

    actions = disabledActions

    try work()

    actions = originalActions
  }
}

// MARK: - Disable All Actions

public extension CALayer {

  private final class NoActionsDelegate: NSObject, CALayerDelegate {

    static let shared = NoActionsDelegate()

    private let null = NSNull()

    func action(for layer: CALayer, forKey event: String) -> CAAction? {
      return null
    }
  }

  /// Cache for disabled subclasses, keyed by the original class’s name.
  private static var subclassCache: [String: AnyClass] = [:]

  /// Execute the block with all actions disabled.
  ///
  /// `CALayer` has implicit animations for some properties, which is not desired in some cases.
  /// This method helps to disable the implicit animations for the layer.
  ///
  /// This method will disable all actions for the layer by either setting the delegate to a custom implementation that
  /// returns `NSNull()` for any action request, or by creating a new subclass and swapping the layer's `action(forKey:)`
  /// implementation to return `NSNull()` for any action request.
  ///
  /// For simplicity, prefer to use `disableActions(for:_:)` if you only need to disable actions for specific keys.
  ///
  /// - Parameter work: The block to execute with actions disabled.
  /// - Throws: Any errors thrown by the block.
  func disableActions(_ work: () throws -> Void) rethrows {
    if self.delegate == nil {
      // if no delegate exists, use the simple delegate to disable actions
      self.delegate = NoActionsDelegate.shared
      try work()
      self.delegate = nil
    } else {
      // if delegate exists, use the subclass approach to disable actions
      assert(Thread.isMainThread, "CALayer.disableActions() must be called on the main thread")

      let originalClass: AnyClass = object_getClass(self)! // swiftlint:disable:this force_unwrapping
      let subclassClassName = "\(originalClass)_DisabledActions"

      // retrieve or create the subclass with disabled actions
      let subclass: AnyClass = onMainSync {
        if let cached = CALayer.subclassCache[subclassClassName] {
          return cached
        }

        // check if the class already exists in the runtime.
        if let theClass = NSClassFromString(subclassClassName) {
          CALayer.subclassCache[subclassClassName] = theClass
          return theClass
        }

        // create a new subclass and cache it
        guard let newClass = objc_allocateClassPair(originalClass, subclassClassName, 0) else {
          assertionFailure("Unable to allocate class pair for \(subclassClassName). Actions will not be disabled.")
          return originalClass
        }

        // Hardcoded type encoding for action(forKey:):
        // '@' : return type (object, i.e. CAAction?),
        // '@' : first hidden parameter (self),
        // ':' : second hidden parameter (_cmd),
        // '@' : explicit object parameter (the key).
        let typeEncoding = "@@:@"

        // create an implementation block that always returns NSNull().
        let block: @convention(block) (CALayer, String) -> Any? = { _, _ in NSNull() }
        let implementation = imp_implementationWithBlock(block)
        let selector = #selector(CALayer.action(forKey:))
        class_addMethod(newClass, selector, implementation, typeEncoding)
        objc_registerClassPair(newClass)

        CALayer.subclassCache[subclassClassName] = newClass

        return newClass
      }

      // temporarily swap the layer's class to the subclass.
      object_setClass(self, subclass)

      try work()

      // restore the original class after the work block.
      object_setClass(self, originalClass)
    }
  }
}

private func onMainSync<T>(_ work: () throws -> T) rethrows -> T {
  if Thread.isMainThread {
    return try work()
  }

  return try DispatchQueue.main.sync {
    try work()
  }
}
