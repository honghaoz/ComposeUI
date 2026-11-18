//
//  UIView+InheritedResizeTimingTests.swift
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

import ChouTiTest

@testable import ComposeUI

class UIView_InheritedResizeTimingTests: XCTestCase {

  func test_outsideAnimation() {
    // given: a view
    let view = makeView()

    // when: resizing it outside an animation block
    view.frame.size.width = 200

    // then: there's no timing to follow
    expect(view.inheritedResizeTiming()) == nil
  }

  func test_curve() {
    for (option, name) in [
      (UIView.AnimationOptions.curveEaseInOut, CAMediaTimingFunctionName.easeInEaseOut),
      (.curveEaseIn, .easeIn),
      (.curveEaseOut, .easeOut),
      (.curveLinear, .linear),
    ] {
      // given: a view
      let view = makeView()

      // when: resizing it in an animation block with a curve
      var timing: AnimationTiming?
      UIView.animate(withDuration: 0.7, delay: 0, options: option) {
        view.frame.size.width = 200
        timing = view.inheritedResizeTiming()
      }

      // then: the timing has the block's duration and curve
      expect(timing) == AnimationTiming(timing: .timingFunction(0.7, CAMediaTimingFunction(name: name)))
      view.layer.removeAllAnimations()
    }
  }

  func test_spring() {
    // given: a view
    let view = makeView()

    // when: resizing it in a spring animation block
    var timing: AnimationTiming?
    UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
      view.frame.size.width = 200
      timing = view.inheritedResizeTiming()
    }

    // then: the timing is UIKit's spring, for the block's duration
    let spring = try? unwrap(view.layer.animation(forKey: "bounds.size") as? CASpringAnimation)
    expect(spring) != nil
    if let spring {
      let descriptor = SpringDescriptor(initialVelocity: spring.initialVelocity, mass: spring.mass, stiffness: spring.stiffness, damping: spring.damping)
      expect(timing) == AnimationTiming(timing: .spring(descriptor, duration: 0.8))
    }
    view.layer.removeAllAnimations()
  }

  func test_spring_bounce() throws {
    guard #available(iOS 17.0, tvOS 17.0, *) else {
      try skip("springs with a bounce need iOS 17 and tvOS 17")
      return
    }

    for (bounce, follows) in [(0.3, true), (0, true), (-0.5, false)] {
      // given: a view
      let view = makeView()

      // when: resizing it in a spring with a bounce, which is overdamped below zero
      var timing: AnimationTiming?
      UIView.animate(springDuration: 0.5, bounce: bounce) {
        view.frame.size.width = 200
        timing = view.inheritedResizeTiming()
      }

      // then: an overdamped spring isn't followed, since the timing's springs clamp it to critical damping
      expect(timing != nil, "bounce \(bounce)") == follows
      view.layer.removeAllAnimations()
    }
  }

  func test_unfollowedBlocks() {
    // given: a view
    let view = makeView()

    // when: resizing it with a delay, a repeat, or keyframes
    var timings: [AnimationTiming?] = []
    UIView.animate(withDuration: 0.5, delay: 0.2, options: []) {
      view.frame.size.width = 200
      timings.append(view.inheritedResizeTiming())
    }
    view.layer.removeAllAnimations()
    UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse]) {
      view.frame.size.width = 300
      timings.append(view.inheritedResizeTiming())
    }
    view.layer.removeAllAnimations()
    UIView.animateKeyframes(withDuration: 0.5, delay: 0) {
      UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
        view.frame.size.width = 200
        timings.append(view.inheritedResizeTiming())
      }
    }
    view.layer.removeAllAnimations()

    // then: none is followed
    expect(timings.count) == 3
    for timing in timings {
      expect(timing) == nil
    }
  }

  func test_propertyAnimator() {
    // given: a view
    let view = makeView()

    // when: resizing it with a property animator
    var timing: AnimationTiming? = .linear()
    let animator = UIViewPropertyAnimator(duration: 0.5, curve: .easeOut) {
      view.frame.size.width = 200
      timing = view.inheritedResizeTiming()
    }
    animator.startAnimation()

    // then: it isn't followed, since the animator can pause and scrub its animations later
    expect(timing) == nil
    animator.stopAnimation(true)
  }

  func test_moveWithoutResize() {
    // given: a view
    let view = makeView()

    // when: moving it in an animation block without resizing it
    var timing: AnimationTiming? = .linear()
    UIView.animate(withDuration: 0.5) {
      view.frame.origin.x = 50
      timing = view.inheritedResizeTiming()
    }

    // then: there's no resize to follow
    expect(timing) == nil
    view.layer.removeAllAnimations()
  }

  func test_severalResizes() {
    // given: a view
    let view = makeView()

    // when: resizing it twice in one transaction in blocks with the same timing
    var timing: AnimationTiming?
    var keys: [String]?
    UIView.animate(withDuration: 0.5) {
      view.frame.size.width = 200
    }
    UIView.animate(withDuration: 0.5) {
      view.frame.size.width = 300
      timing = view.inheritedResizeTiming()
      keys = view.inheritedResize()?.animationKeys
    }

    // then: the timing is the blocks' timing, with the keys of both of UIKit's animations
    expect(timing) == AnimationTiming(timing: .timingFunction(0.5, CAMediaTimingFunction(name: .easeInEaseOut)))
    expect(keys?.count) == 2
    expect(Set(keys ?? []).count) == 2

    // when: resizing it again in a block of the same duration with another curve
    UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear) {
      view.frame.size.width = 400
      timing = view.inheritedResizeTiming()
    }

    // then: the resizes disagree, so none is followed
    expect(timing) == nil
    view.layer.removeAllAnimations()

    // when: resizing it in a block, then again in a block of another duration with a layout
    UIView.animate(withDuration: 0.3) {
      view.frame.size.width = 200
    }
    UIView.animate(withDuration: 0.5) {
      view.frame.size.width = 300
      timing = view.inheritedResizeTiming()
    }

    // then: the view shows the sum of both, which no one timing follows
    expect(timing) == nil
    view.layer.removeAllAnimations()

    // when: resizing it in a block, then laying it out in a block of another duration without resizing it
    UIView.animate(withDuration: 0.3) {
      view.frame.size.width = 100
    }
    UIView.animate(withDuration: 0.5) {
      timing = view.inheritedResizeTiming()
    }

    // then: the timing is the resize's, which the view shows
    expect(timing) == AnimationTiming(timing: .timingFunction(0.3, CAMediaTimingFunction(name: .easeInEaseOut)))
    view.layer.removeAllAnimations()
  }

  func test_resizeAnimationChecks() {
    // given: resize animations of UIKit's form, and each change that makes one not followable
    let timingFunction = CAMediaTimingFunction(name: .easeIn)
    func basic(_ change: (CABasicAnimation) -> Void = { _ in }) -> CABasicAnimation {
      let animation = CABasicAnimation(keyPath: "bounds.size")
      animation.isAdditive = true
      animation.fromValue = CGSize(width: -100, height: 0)
      animation.toValue = CGSize.zero
      animation.duration = 0.5
      animation.timingFunction = timingFunction
      change(animation)
      return animation
    }
    final class BasicSubclass: CABasicAnimation {}
    let subclass = BasicSubclass(keyPath: "bounds.size")
    subclass.isAdditive = true
    subclass.duration = 0.5
    let cases: [(String, CAAnimation, AnimationTiming?)] = [
      ("plain", basic(), AnimationTiming(timing: .timingFunction(0.5, timingFunction))),
      ("no timing function", basic { $0.timingFunction = nil }, AnimationTiming(timing: .timingFunction(0.5, CAMediaTimingFunction(name: .linear)))),
      ("speed", basic { $0.speed = 2 }, nil),
      ("time offset", basic { $0.timeOffset = 0.1 }, nil),
      ("repeat count", basic { $0.repeatCount = 2 }, nil),
      ("repeat duration", basic { $0.repeatDuration = 1 }, nil),
      ("autoreverses", basic { $0.autoreverses = true }, nil),
      ("subclass", subclass, nil),
    ]

    for (name, animation, expected) in cases {
      // given: a view
      let view = makeView()

      // when: the animation is the view's resize animation in an animation block
      var timing: AnimationTiming?
      UIView.animate(withDuration: 0.5) {
        view.layer.add(animation, forKey: "resize")
        timing = view.inheritedResizeTiming()
      }

      // then: only an animation that the timing reproduces is followed
      expect(timing, name) == expected
      view.layer.removeAllAnimations()
    }

    // when: the view has other animations in an animation block: an app's own, a scheduled one, and another key path's
    let view = makeView()
    var timing: AnimationTiming? = .linear()
    UIView.animate(withDuration: 0.5) {
      view.layer.add(basic { $0.isAdditive = false }, forKey: "own")
      view.layer.add(basic { $0.beginTime = 0.2 }, forKey: "scheduled")
      view.layer.add(basic { $0.keyPath = "position" }, forKey: "position")
      view.layer.add(CAAnimationGroup(), forKey: "group")
      timing = view.inheritedResizeTiming()
    }

    // then: none is a resize to follow
    expect(timing) == nil
    view.layer.removeAllAnimations()
  }

  // MARK: - Helpers

  private func makeView() -> UIView {
    UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
  }
}

#endif
