//
//  AnimationTimingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
//

import XCTest

import ComposeUI

class AnimationTimingTests: XCTestCase {

    func test_linear() {
        // test default values
        do {
            let timing = AnimationTiming.linear()
            XCTAssertEqual(timing.timing, .timingFunction(ComposeAnimations.defaultAnimationDuration, CAMediaTimingFunction(name: .linear)))
            XCTAssertEqual(timing.timing.duration, ComposeAnimations.defaultAnimationDuration)
            XCTAssertEqual(timing.delay, 0)
            XCTAssertEqual(timing.speed, 1)
        }

        // test custom values
        do {
            let timing = AnimationTiming.linear(duration: 2, delay: 2, speed: 2)
            XCTAssertEqual(timing.timing, .timingFunction(2, CAMediaTimingFunction(name: .linear)))
            XCTAssertEqual(timing.timing.duration, 2)
            XCTAssertEqual(timing.delay, 2)
            XCTAssertEqual(timing.speed, 2)
        }
    }

    func test_easeIn() {
        // test default values
        do {
            let timing = AnimationTiming.easeIn()
            XCTAssertEqual(timing.timing, .timingFunction(ComposeAnimations.defaultAnimationDuration, CAMediaTimingFunction(name: .easeIn)))
            XCTAssertEqual(timing.timing.duration, ComposeAnimations.defaultAnimationDuration)
            XCTAssertEqual(timing.delay, 0)
            XCTAssertEqual(timing.speed, 1)
        }

        // test custom values
        do {
            let timing = AnimationTiming.easeIn(duration: 2, delay: 2, speed: 2)
            XCTAssertEqual(timing.timing, .timingFunction(2, CAMediaTimingFunction(name: .easeIn)))
            XCTAssertEqual(timing.timing.duration, 2)
            XCTAssertEqual(timing.delay, 2)
            XCTAssertEqual(timing.speed, 2)
        }
    }

    func test_easeOut() {
        // test default values
        do {
            let timing = AnimationTiming.easeOut()
            XCTAssertEqual(timing.timing, .timingFunction(ComposeAnimations.defaultAnimationDuration, CAMediaTimingFunction(name: .easeOut)))
            XCTAssertEqual(timing.timing.duration, ComposeAnimations.defaultAnimationDuration)
            XCTAssertEqual(timing.delay, 0)
            XCTAssertEqual(timing.speed, 1)
        }

        // test custom values
        do {
            let timing = AnimationTiming.easeOut(duration: 2, delay: 2, speed: 2)
            XCTAssertEqual(timing.timing, .timingFunction(2, CAMediaTimingFunction(name: .easeOut)))
            XCTAssertEqual(timing.timing.duration, 2)
            XCTAssertEqual(timing.delay, 2)
            XCTAssertEqual(timing.speed, 2)
        }
    }

    func test_easeInEaseOut() {
        // test default values
        do {
            let timing = AnimationTiming.easeInEaseOut()
            XCTAssertEqual(timing.timing, .timingFunction(ComposeAnimations.defaultAnimationDuration, CAMediaTimingFunction(name: .easeInEaseOut)))
            XCTAssertEqual(timing.timing.duration, ComposeAnimations.defaultAnimationDuration)
            XCTAssertEqual(timing.delay, 0)
            XCTAssertEqual(timing.speed, 1)
        }

        // test custom values
        do {
            let timing = AnimationTiming.easeInEaseOut(duration: 2, delay: 2, speed: 2)
            XCTAssertEqual(timing.timing, .timingFunction(2, CAMediaTimingFunction(name: .easeInEaseOut)))
            XCTAssertEqual(timing.timing.duration, 2)
            XCTAssertEqual(timing.delay, 2)
            XCTAssertEqual(timing.speed, 2)
        }
    }

    func test_spring() {
        // test default values
        do {
            let timing = AnimationTiming.spring()
            let springDescriptor = SpringDescriptor(dampingRatio: ComposeAnimations.defaultSpringDampingRatio, response: ComposeAnimations.defaultSpringResponse, initialVelocity: 0)
            XCTAssertEqual(timing.timing, .spring(springDescriptor, duration: nil))
            XCTAssertEqual(timing.timing.duration, springDescriptor.settlingDuration())
            XCTAssertEqual(timing.delay, 0)
            XCTAssertEqual(timing.speed, 1)
        }

        // test custom values
        do {
            let timing = AnimationTiming.spring(dampingRatio: 0.5, response: 0.5, initialVelocity: 0.5, duration: 2, delay: 2, speed: 2)
            XCTAssertEqual(timing.timing, .spring(SpringDescriptor(dampingRatio: 0.5, response: 0.5, initialVelocity: 0.5), duration: 2))
            XCTAssertEqual(timing.timing.duration, 2)
            XCTAssertEqual(timing.delay, 2)
            XCTAssertEqual(timing.speed, 2)
        }
    }
}
