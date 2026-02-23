//
//  AnimationTimingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
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
