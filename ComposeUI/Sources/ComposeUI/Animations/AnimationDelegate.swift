//
//  AnimationDelegate.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/25/21.
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

import Foundation
import QuartzCore

/// A `CAAnimation` delegate object.
///
/// `CAAnimation` strongly retain `delegate`, you can just assign the delegate without retaining it.
final class AnimationDelegate: NSObject, CAAnimationDelegate {

  private let animationDidStart: ((_ animation: CAAnimation) -> Void)?
  private let animationDidStop: ((_ animation: CAAnimation, _ finished: Bool) -> Void)?

  private var didStart: Bool = false
  private var didStop: Bool = false

  /// Create a new animation delegate.
  ///
  /// - Parameters:
  ///   - animationDidStart: The block to be called when the animation starts.
  ///   - animationDidStop: The block to be called when the animation stops.
  init(animationDidStart: ((_ animation: CAAnimation) -> Void)? = nil,
       animationDidStop: ((_ animation: CAAnimation, _ finished: Bool) -> Void)? = nil)
  {
    self.animationDidStart = animationDidStart
    self.animationDidStop = animationDidStop
  }

  func animationDidStart(_ animation: CAAnimation) {
    guard !didStart else {
      return
    }
    didStart = true
    animationDidStart?(animation)
  }

  func animationDidStop(_ animation: CAAnimation, finished: Bool) {
    guard !didStop else {
      return
    }
    didStop = true
    animationDidStop?(animation, finished)
  }
}
