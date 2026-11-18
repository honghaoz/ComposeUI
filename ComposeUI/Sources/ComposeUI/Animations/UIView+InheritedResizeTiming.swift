//
//  UIView+InheritedResizeTiming.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/26.
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

#if canImport(UIKit)

import UIKit

extension UIView {

  /// The timing of the animation that UIKit resizes the view with, for a layout that runs in an animation block, or
  /// `nil` when the view doesn't resize in an animation, or resizes in one whose animation the timing can't reproduce.
  ///
  /// UIKit runs a layout inside an animation for a rotation, for `layoutIfNeeded()` in an animation block, and for the
  /// `.layoutSubviews` animation option. UIKit doesn't say how it animates, so the timing is read from the additive
  /// `bounds.size` animations that UIKit adds to the view's layer in the current transaction, and is `nil` for what
  /// doesn't match what was verified on iOS 27: a delay, a repeat, an overdamped spring, a property animator, which can
  /// pause or scrub its own animations later, or several resize animations that disagree, such as those of two blocks
  /// with different durations, whose sum the view shows.
  ///
  /// - Returns: The timing, or `nil`.
  func inheritedResizeTiming() -> AnimationTiming? {
    inheritedResize()?.timing
  }

  /// The timing of the animation that UIKit resizes the view with and the keys of its animations, see
  /// `inheritedResizeTiming()`.
  ///
  /// - Returns: The timing and the keys, or `nil`.
  func inheritedResize() -> (timing: AnimationTiming, animationKeys: [String])? {
    guard UIView.inheritedAnimationDuration > 0, let keys = layer.unbridgedAnimationKeys else {
      return nil
    }

    var resize: (timing: AnimationTiming, animationKeys: [String])?
    for key in keys {
      guard let animation = layer.animation(forKey: key) as? CAPropertyAnimation,
            // Core Animation gives an animation that begins at the commit its begin time then, so a begin time of zero
            // tells an animation of this transaction without a delay, while UIKit sets a delay as the begin time
            animation.beginTime == 0
      else {
        continue
      }

      switch animation.keyPath {
      case Constants.resizeKeyPath:
        // an animation of the app's own replaces the size. each of UIKit's adds its part, so the content follows them
        // only when they share a timing, whichever block they come from
        guard animation.isAdditive else {
          continue
        }
        guard let animationTiming = Self.timing(of: animation), resize == nil || resize?.timing == animationTiming else {
          return nil
        }
        resize = (animationTiming, (resize?.animationKeys ?? []) + [key])
      case Constants.propertyAnimatorPacingKeyPath:
        // a property animator can pause and scrub the animations it made after the layout, which animations of the
        // content wouldn't follow
        return nil
      default:
        continue
      }
    }
    return resize
  }

  /// The timing that reproduces a resize animation of UIKit's, or `nil` when it can't.
  ///
  /// - Parameter animation: The animation.
  /// - Returns: The timing, or `nil`.
  private static func timing(of animation: CAPropertyAnimation) -> AnimationTiming? {
    guard animation.speed == 1, animation.timeOffset == 0, animation.repeatCount == 0, animation.repeatDuration == 0,
          !animation.autoreverses
    else {
      return nil
    }

    // a subclass of the app's or of UIKit's can run differently from its superclass
    if type(of: animation) == CASpringAnimation.self {
      let spring = unsafeDowncast(animation, to: CASpringAnimation.self)
      if #available(iOS 17.0, tvOS 17.0, *), spring.allowsOverdamping, spring.damping > 2 * (spring.stiffness * spring.mass).squareRoot() {
        // the timing's springs clamp an overdamped spring to critical damping
        return nil
      }
      let descriptor = SpringDescriptor(initialVelocity: spring.initialVelocity, mass: spring.mass, stiffness: spring.stiffness, damping: spring.damping)
      return AnimationTiming(timing: .spring(descriptor, duration: spring.duration))
    } else if type(of: animation) == CABasicAnimation.self {
      let basic = unsafeDowncast(animation, to: CABasicAnimation.self)
      return AnimationTiming(timing: .timingFunction(basic.duration, basic.timingFunction ?? CAMediaTimingFunction(name: .linear)))
    } else {
      return nil
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The key path of the animation that UIKit resizes a view's layer with.
    static let resizeKeyPath = "bounds.size"

    /// The key path of the animation that a property animator paces its animations with.
    static let propertyAnimatorPacingKeyPath = "uiFractionalProgress"
  }
}

#endif
