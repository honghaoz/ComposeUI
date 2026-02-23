//
//  CABasicAnimation+AnimationTimingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
//

import XCTest

@_spi(Private) @testable import ComposeUI

class CABasicAnimation_AnimationTimingTests: XCTestCase {

    func test_makeAnimation() {
        // timing function
        do {
            let animation = CABasicAnimation.makeAnimation(AnimationTiming.easeInEaseOut())
            XCTAssertEqual(animation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
            XCTAssertEqual(animation.duration, ComposeAnimations.defaultAnimationDuration)
            XCTAssertEqual(animation.speed, 1)
            XCTAssertEqual(animation.fillMode, .both)
        }

        // spring
        do {
            let timing = AnimationTiming.spring(dampingRatio: 0.5, response: 0.5, initialVelocity: 0.1, duration: nil, delay: 1, speed: 2)
            let animation = CABasicAnimation.makeAnimation(timing)

            let springAnimation = try XCTUnwrap(animation as? CASpringAnimation)
            XCTAssertEqual(springAnimation.initialVelocity, 0.1)
            XCTAssertEqual(springAnimation.mass, 1)
            XCTAssertEqual(springAnimation.damping, 12.566370614359172)
            XCTAssertEqual(springAnimation.stiffness, 157.91367041742973)
            XCTAssertEqual(springAnimation.duration, 0.9148578261552982)

            XCTAssertEqual(springAnimation.speed, 2)
            XCTAssertEqual(springAnimation.fillMode, .both)
        } catch {
            XCTFail("error: \(error)")
        }
    }
}
