//
//  AnimationTimingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
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
