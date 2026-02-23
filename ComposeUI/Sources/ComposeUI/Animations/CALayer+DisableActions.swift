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
  /// layer.disableActions(for: ["position", "bounds", "transform"]) {
  ///   layer.frame = newFrame
  ///   layer.transform = CATransform3DIdentity
  /// }
  /// ```
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
