//
//  SpringDescriptorTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/25/21.
//

import QuartzCore
import XCTest

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

        XCTAssertEqual(descriptor.initialVelocity, 10)
        XCTAssertEqual(descriptor.mass, 2)
        XCTAssertEqual(descriptor.stiffness, 300)
        XCTAssertEqual(descriptor.damping, 20)
    }

    func test_init_withPhysicsParameters_defaults() {
        let descriptor = SpringDescriptor(
            mass: 1,
            stiffness: 100,
            damping: 10
        )

        XCTAssertEqual(descriptor.initialVelocity, 0)
        XCTAssertEqual(descriptor.mass, 1)
        XCTAssertEqual(descriptor.stiffness, 100)
        XCTAssertEqual(descriptor.damping, 10)
    }

    // MARK: - Intuitive Initialization

    func test_init_withDampingRatioAndResponse() {
        let descriptor = SpringDescriptor(
            dampingRatio: 0.8,
            response: 0.5
        )

        // Verify that physics parameters are calculated
        XCTAssertEqual(descriptor.initialVelocity, 0)
        XCTAssertEqual(descriptor.mass, 1)

        // stiffness = pow(2 * π / response, 2)
        let expectedStiffness = pow(2 * .pi / 0.5, 2)
        XCTAssertEqual(descriptor.stiffness, expectedStiffness, accuracy: 1e-6)

        // damping = 4 * π * dampingRatio / response
        let expectedDamping = 4 * .pi * 0.8 / 0.5
        XCTAssertEqual(descriptor.damping, expectedDamping, accuracy: 1e-6)
    }

    func test_init_withDampingRatioAndResponse_withInitialVelocity() {
        let descriptor = SpringDescriptor(
            dampingRatio: 0.5,
            response: 0.6,
            initialVelocity: 15
        )

        XCTAssertEqual(descriptor.initialVelocity, 15)
        XCTAssertEqual(descriptor.mass, 1)
    }

    func test_init_clampsDampingRatio() {
        // Test lower bound
        let descriptorLow = SpringDescriptor(
            dampingRatio: -0.5,
            response: 0.5
        )
        // damping = 4 * π * 0 / response = 0
        XCTAssertEqual(descriptorLow.damping, 0)

        // Test upper bound
        let descriptorHigh = SpringDescriptor(
            dampingRatio: 1.5,
            response: 0.5
        )
        // damping = 4 * π * 1.0 / 0.5
        let expectedDamping = 4 * .pi * 1.0 / 0.5
        XCTAssertEqual(descriptorHigh.damping, expectedDamping, accuracy: 1e-6)

        // Test exact bounds
        let descriptorZero = SpringDescriptor(
            dampingRatio: 0,
            response: 0.5
        )
        XCTAssertEqual(descriptorZero.damping, 0)

        let descriptorOne = SpringDescriptor(
            dampingRatio: 1.0,
            response: 0.5
        )
        let expectedDampingOne = 4 * .pi * 1.0 / 0.5
        XCTAssertEqual(descriptorOne.damping, expectedDampingOne, accuracy: 1e-6)
    }

    func test_init_clampsResponseToMinimum() {
        // Test very small response
        let descriptorSmall = SpringDescriptor(
            dampingRatio: 0.5,
            response: 0.001
        )
        // response should be clamped to 0.01
        let expectedStiffness = pow(2 * .pi / 0.01, 2)
        XCTAssertEqual(descriptorSmall.stiffness, expectedStiffness, accuracy: 1e-6)

        // Test zero response
        let descriptorZero = SpringDescriptor(
            dampingRatio: 0.5,
            response: 0
        )
        // response should be clamped to 0.01
        XCTAssertEqual(descriptorZero.stiffness, expectedStiffness, accuracy: 1e-6)

        // Test negative response
        let descriptorNegative = SpringDescriptor(
            dampingRatio: 0.5,
            response: -0.5
        )
        // response should be clamped to 0.01
        XCTAssertEqual(descriptorNegative.stiffness, expectedStiffness, accuracy: 1e-6)
    }

    // MARK: - Duration Methods

    func test_settlingDuration() {
        let descriptor = SpringDescriptor(
            dampingRatio: 0.8,
            response: 0.5
        )

        XCTAssertEqual(descriptor.settlingDuration(), 0.7714094006693448, accuracy: 1e-6)

        // Fast spring
        let fastSpring = SpringDescriptor(
            dampingRatio: 1.0,
            response: 0.2
        )
        XCTAssertEqual(fastSpring.settlingDuration(), 0.3, accuracy: 1e-6)

        // Slow spring
        let slowSpring = SpringDescriptor(
            dampingRatio: 0.3,
            response: 1.5
        )
        XCTAssertEqual(slowSpring.settlingDuration(), 5.71461784505134, accuracy: 1e-6)
    }

    func test_perceptualDuration() {
        let descriptor = SpringDescriptor(
            dampingRatio: 0.7,
            response: 0.6
        )

        XCTAssertEqual(descriptor.perceptualDuration(), 0.8159891974978289, accuracy: 1e-6)
    }

    func test_perceptualDuration_isReasonable() {
        let descriptor = SpringDescriptor(
            dampingRatio: 0.8,
            response: 0.5
        )

        let perceptual = descriptor.perceptualDuration()
        let settling = descriptor.settlingDuration()

        // Perceptual duration should be less than or equal to settling duration
        XCTAssertLessThanOrEqual(perceptual, settling)
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
        XCTAssertEqual(descriptor1, descriptor2)
        XCTAssertEqual(descriptor1.hashValue, descriptor2.hashValue)

        // Different descriptors should not be equal
        XCTAssertNotEqual(descriptor1, descriptor3)
    }

    // MARK: - Real-world Examples

    func test_bouncySpring() {
        let bouncy = SpringDescriptor(
            dampingRatio: 0.3,
            response: 0.5
        )

        XCTAssertEqual(bouncy.mass, 1)
        XCTAssertGreaterThan(bouncy.stiffness, 0)
        XCTAssertGreaterThan(bouncy.damping, 0)

        // Bouncy springs should have lower damping relative to stiffness
        let criticalDamping = 2 * sqrt(bouncy.mass * bouncy.stiffness)
        XCTAssertLessThan(bouncy.damping, criticalDamping)
    }

    func test_criticallyDampedSpring() {
        let criticallyDamped = SpringDescriptor(
            dampingRatio: 1.0,
            response: 0.5
        )

        XCTAssertEqual(criticallyDamped.mass, 1)
        XCTAssertGreaterThan(criticallyDamped.stiffness, 0)

        // For critically damped: damping = 2 * sqrt(mass * stiffness)
        let criticalDamping = 2 * sqrt(criticallyDamped.mass * criticallyDamped.stiffness)
        XCTAssertEqual(criticallyDamped.damping, criticalDamping, accuracy: 1e-6)
    }

    func test_fastResponsiveSpring() {
        let fast = SpringDescriptor(
            dampingRatio: 0.8,
            response: 0.3
        )

        let duration = fast.settlingDuration()
        XCTAssertLessThan(duration, 1.0) // Should settle quickly
    }

    func test_slowHeavySpring() {
        let slow = SpringDescriptor(
            dampingRatio: 0.7,
            response: 1.5
        )

        let duration = slow.settlingDuration()
        XCTAssertGreaterThan(duration, 1.0) // Should take longer to settle
    }
}
