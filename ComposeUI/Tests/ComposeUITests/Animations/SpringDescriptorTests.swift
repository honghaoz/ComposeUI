//
//  SpringDescriptorTests.swift
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

import QuartzCore

import ChouTiTest

@testable import ComposeUI

class SpringDescriptorTests: XCTestCase {

  // MARK: - Physics-based Initialization

  func test_init_withPhysicsParameters() {
    let descriptor = SpringDescriptor(
      initialVelocity: 10,
      mass: 2,
      stiffness: 300,
      damping: 20
    )

    expect(descriptor.initialVelocity) == 10
    expect(descriptor.mass) == 2
    expect(descriptor.stiffness) == 300
    expect(descriptor.damping) == 20
  }

  func test_init_withPhysicsParameters_defaults() {
    let descriptor = SpringDescriptor(
      mass: 1,
      stiffness: 100,
      damping: 10
    )

    expect(descriptor.initialVelocity) == 0
    expect(descriptor.mass) == 1
    expect(descriptor.stiffness) == 100
    expect(descriptor.damping) == 10
  }

  // MARK: - Intuitive Initialization

  func test_init_withDampingRatioAndResponse() {
    let descriptor = SpringDescriptor(
      dampingRatio: 0.8,
      response: 0.5
    )

    // Verify that physics parameters are calculated
    expect(descriptor.initialVelocity) == 0
    expect(descriptor.mass) == 1

    // stiffness = pow(2 * π / response, 2)
    let expectedStiffness = pow(2 * .pi / 0.5, 2)
    expect(descriptor.stiffness).to(beApproximatelyEqual(to: expectedStiffness, within: 1e-6))

    // damping = 4 * π * dampingRatio / response
    let expectedDamping = 4 * .pi * 0.8 / 0.5
    expect(descriptor.damping).to(beApproximatelyEqual(to: expectedDamping, within: 1e-6))
  }

  func test_init_withDampingRatioAndResponse_withInitialVelocity() {
    let descriptor = SpringDescriptor(
      dampingRatio: 0.5,
      response: 0.6,
      initialVelocity: 15
    )

    expect(descriptor.initialVelocity) == 15
    expect(descriptor.mass) == 1
  }

  func test_init_clampsDampingRatio() {
    // Test lower bound
    let descriptorLow = SpringDescriptor(
      dampingRatio: -0.5,
      response: 0.5
    )
    // damping = 4 * π * 0 / response = 0
    expect(descriptorLow.damping) == 0

    // Test upper bound
    let descriptorHigh = SpringDescriptor(
      dampingRatio: 1.5,
      response: 0.5
    )
    // damping = 4 * π * 1.0 / 0.5
    let expectedDamping = 4 * .pi * 1.0 / 0.5
    expect(descriptorHigh.damping).to(beApproximatelyEqual(to: expectedDamping, within: 1e-6))

    // Test exact bounds
    let descriptorZero = SpringDescriptor(
      dampingRatio: 0,
      response: 0.5
    )
    expect(descriptorZero.damping) == 0

    let descriptorOne = SpringDescriptor(
      dampingRatio: 1.0,
      response: 0.5
    )
    let expectedDampingOne = 4 * .pi * 1.0 / 0.5
    expect(descriptorOne.damping).to(beApproximatelyEqual(to: expectedDampingOne, within: 1e-6))
  }

  func test_init_clampsResponseToMinimum() {
    // Test very small response
    let descriptorSmall = SpringDescriptor(
      dampingRatio: 0.5,
      response: 0.001
    )
    // response should be clamped to 0.01
    let expectedStiffness = pow(2 * .pi / 0.01, 2)
    expect(descriptorSmall.stiffness).to(beApproximatelyEqual(to: expectedStiffness, within: 1e-6))

    // Test zero response
    let descriptorZero = SpringDescriptor(
      dampingRatio: 0.5,
      response: 0
    )
    // response should be clamped to 0.01
    expect(descriptorZero.stiffness).to(beApproximatelyEqual(to: expectedStiffness, within: 1e-6))

    // Test negative response
    let descriptorNegative = SpringDescriptor(
      dampingRatio: 0.5,
      response: -0.5
    )
    // response should be clamped to 0.01
    expect(descriptorNegative.stiffness).to(beApproximatelyEqual(to: expectedStiffness, within: 1e-6))
  }

  // MARK: - Duration Methods

  func test_settlingDuration() {
    let descriptor = SpringDescriptor(
      dampingRatio: 0.8,
      response: 0.5
    )

    expect(descriptor.settlingDuration()).to(beApproximatelyEqual(to: 0.7714094006693448, within: 1e-6))

    // Fast spring
    let fastSpring = SpringDescriptor(
      dampingRatio: 1.0,
      response: 0.2
    )
    expect(fastSpring.settlingDuration()).to(beApproximatelyEqual(to: 0.3, within: 1e-6))

    // Slow spring
    let slowSpring = SpringDescriptor(
      dampingRatio: 0.3,
      response: 1.5
    )
    expect(slowSpring.settlingDuration()).to(beApproximatelyEqual(to: 5.71461784505134, within: 1e-6))
  }

  func test_perceptualDuration() {
    let descriptor = SpringDescriptor(
      dampingRatio: 0.7,
      response: 0.6
    )

    expect(descriptor.perceptualDuration()).to(beApproximatelyEqual(to: 0.8159891974978289, within: 1e-6))
  }

  func test_perceptualDuration_isReasonable() {
    let descriptor = SpringDescriptor(
      dampingRatio: 0.8,
      response: 0.5
    )

    let perceptual = descriptor.perceptualDuration()
    let settling = descriptor.settlingDuration()

    // Perceptual duration should be less than or equal to settling duration
    expect(perceptual) <= settling
  }

  func test_duration_withEpsilon() throws {
    let descriptor = SpringDescriptor(
      dampingRatio: 0.6,
      response: 0.5
    )

    try expect(
      descriptor.duration(epsilon: 0.005).unwrap()
    ).to(
      beApproximatelyEqual(to: 0.7769325148649515, within: 1e-6)
    )
  }

  // MARK: - Hashable

  func test_hashable() {
    let descriptor1 = SpringDescriptor(
      initialVelocity: 5,
      mass: 1,
      stiffness: 200,
      damping: 15
    )

    let descriptor2 = SpringDescriptor(
      initialVelocity: 5,
      mass: 1,
      stiffness: 200,
      damping: 15
    )

    let descriptor3 = SpringDescriptor(
      initialVelocity: 10,
      mass: 1,
      stiffness: 200,
      damping: 15
    )

    // Equal descriptors should be equal
    expect(descriptor1) == descriptor2
    expect(descriptor1.hashValue) == descriptor2.hashValue

    // Different descriptors should not be equal
    expect(descriptor1) != descriptor3
  }

  // MARK: - Real-world Examples

  func test_bouncySpring() {
    let bouncy = SpringDescriptor(
      dampingRatio: 0.3,
      response: 0.5
    )

    expect(bouncy.mass) == 1
    expect(bouncy.stiffness) > 0
    expect(bouncy.damping) > 0

    // Bouncy springs should have lower damping relative to stiffness
    let criticalDamping = 2 * sqrt(bouncy.mass * bouncy.stiffness)
    expect(bouncy.damping) < criticalDamping
  }

  func test_criticallyDampedSpring() {
    let criticallyDamped = SpringDescriptor(
      dampingRatio: 1.0,
      response: 0.5
    )

    expect(criticallyDamped.mass) == 1
    expect(criticallyDamped.stiffness) > 0

    // For critically damped: damping = 2 * sqrt(mass * stiffness)
    let criticalDamping = 2 * sqrt(criticallyDamped.mass * criticallyDamped.stiffness)
    expect(criticallyDamped.damping).to(beApproximatelyEqual(to: criticalDamping, within: 1e-6))
  }

  func test_fastResponsiveSpring() {
    let fast = SpringDescriptor(
      dampingRatio: 0.8,
      response: 0.3
    )

    let duration = fast.settlingDuration()
    expect(duration) < 1.0 // Should settle quickly
  }

  func test_slowHeavySpring() {
    let slow = SpringDescriptor(
      dampingRatio: 0.7,
      response: 1.5
    )

    let duration = slow.settlingDuration()
    expect(duration) > 1.0 // Should take longer to settle
  }
}
