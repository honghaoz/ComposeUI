//
//  CABasicAnimation+AnimationTimingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
//

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class CABasicAnimation_AnimationTimingTests: XCTestCase {

  func test_makeAnimation() {
    // timing function
    do {
      let animation = CABasicAnimation.makeAnimation(AnimationTiming.easeInEaseOut())
      expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
      expect(animation.duration) == Animations.defaultAnimationDuration
      expect(animation.speed) == 1
      expect(animation.fillMode) == .both
    }

    // spring
    do {
      let timing = AnimationTiming.spring(dampingRatio: 0.5, response: 0.5, initialVelocity: 0.1, duration: nil, delay: 1, speed: 2)
      let animation = CABasicAnimation.makeAnimation(timing)

      let springAnimation = try unwrap(animation as? CASpringAnimation)
      expect(springAnimation.initialVelocity) == 0.1
      expect(springAnimation.mass) == 1
      expect(springAnimation.damping) == 12.566370614359172
      expect(springAnimation.stiffness) == 157.91367041742973
      expect(springAnimation.duration) == 0.9148578261552982

      expect(springAnimation.speed) == 2
      expect(springAnimation.fillMode) == .both
    } catch {
      fail("error: \(error)")
    }
  }
}
