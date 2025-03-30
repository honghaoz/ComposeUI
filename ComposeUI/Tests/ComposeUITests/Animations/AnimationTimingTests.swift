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

import ChouTiTest

import ComposeUI

class AnimationTimingTests: XCTestCase {

  func test_linear() {
    // test default values
    do {
      let timing = AnimationTiming.linear()
      expect(timing.timing) == .timingFunction(Animations.defaultAnimationDuration, CAMediaTimingFunction(name: .linear))
      expect(timing.timing.duration) == Animations.defaultAnimationDuration
      expect(timing.delay) == 0
      expect(timing.speed) == 1
    }

    // test custom values
    do {
      let timing = AnimationTiming.linear(duration: 2, delay: 2, speed: 2)
      expect(timing.timing) == .timingFunction(2, CAMediaTimingFunction(name: .linear))
      expect(timing.timing.duration) == 2
      expect(timing.delay) == 2
      expect(timing.speed) == 2
    }
  }

  func test_easeIn() {
    // test default values
    do {
      let timing = AnimationTiming.easeIn()
      expect(timing.timing) == .timingFunction(Animations.defaultAnimationDuration, CAMediaTimingFunction(name: .easeIn))
      expect(timing.timing.duration) == Animations.defaultAnimationDuration
      expect(timing.delay) == 0
      expect(timing.speed) == 1
    }

    // test custom values
    do {
      let timing = AnimationTiming.easeIn(duration: 2, delay: 2, speed: 2)
      expect(timing.timing) == .timingFunction(2, CAMediaTimingFunction(name: .easeIn))
      expect(timing.timing.duration) == 2
      expect(timing.delay) == 2
      expect(timing.speed) == 2
    }
  }

  func test_easeOut() {
    // test default values
    do {
      let timing = AnimationTiming.easeOut()
      expect(timing.timing) == .timingFunction(Animations.defaultAnimationDuration, CAMediaTimingFunction(name: .easeOut))
      expect(timing.timing.duration) == Animations.defaultAnimationDuration
      expect(timing.delay) == 0
      expect(timing.speed) == 1
    }

    // test custom values
    do {
      let timing = AnimationTiming.easeOut(duration: 2, delay: 2, speed: 2)
      expect(timing.timing) == .timingFunction(2, CAMediaTimingFunction(name: .easeOut))
      expect(timing.timing.duration) == 2
      expect(timing.delay) == 2
      expect(timing.speed) == 2
    }
  }

  func test_easeInEaseOut() {
    // test default values
    do {
      let timing = AnimationTiming.easeInEaseOut()
      expect(timing.timing) == .timingFunction(Animations.defaultAnimationDuration, CAMediaTimingFunction(name: .easeInEaseOut))
      expect(timing.timing.duration) == Animations.defaultAnimationDuration
      expect(timing.delay) == 0
      expect(timing.speed) == 1
    }

    // test custom values
    do {
      let timing = AnimationTiming.easeInEaseOut(duration: 2, delay: 2, speed: 2)
      expect(timing.timing) == .timingFunction(2, CAMediaTimingFunction(name: .easeInEaseOut))
      expect(timing.timing.duration) == 2
      expect(timing.delay) == 2
      expect(timing.speed) == 2
    }
  }

  func test_spring() {
    // test default values
    do {
      let timing = AnimationTiming.spring()
      let springDescriptor = SpringDescriptor(dampingRatio: Animations.defaultSpringDampingRatio, response: Animations.defaultSpringResponse, initialVelocity: 0)
      expect(timing.timing) == .spring(springDescriptor, duration: nil)
      expect(timing.timing.duration) == springDescriptor.settlingDuration()
      expect(timing.delay) == 0
      expect(timing.speed) == 1
    }

    // test custom values
    do {
      let timing = AnimationTiming.spring(dampingRatio: 0.5, response: 0.5, initialVelocity: 0.5, duration: 2, delay: 2, speed: 2)
      expect(timing.timing) == .spring(SpringDescriptor(dampingRatio: 0.5, response: 0.5, initialVelocity: 0.5), duration: 2)
      expect(timing.timing.duration) == 2
      expect(timing.delay) == 2
      expect(timing.speed) == 2
    }
  }
}
