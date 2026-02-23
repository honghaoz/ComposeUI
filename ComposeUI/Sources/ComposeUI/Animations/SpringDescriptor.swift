//
//  SpringDescriptor.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/25/21.
//

import Foundation
import QuartzCore

/// A descriptor for a spring animation.
public struct SpringDescriptor: Hashable {

    /// The initial velocity of the object attached to the spring.
    public let initialVelocity: CGFloat

    /// The mass of the object attached to the end of the spring. Must be greater than 0.
    public let mass: CGFloat

    /// The spring stiffness coefficient. Must be greater than 0.
    public let stiffness: CGFloat

    /// The damping coefficient. Must be greater than or equal to 0.
    public let damping: CGFloat

    /// Creates a spring descriptor with physics parameters.
    ///
    /// - Parameters:
    ///   - initialVelocity: The initial velocity of the object.
    ///   - mass: The mass of the object attached to the spring.
    ///   - stiffness: The spring stiffness coefficient.
    ///   - damping: The damping coefficient.
    public init(initialVelocity: CGFloat = 0, mass: CGFloat, stiffness: CGFloat, damping: CGFloat) {
        self.initialVelocity = initialVelocity
        self.mass = mass
        self.stiffness = stiffness
        self.damping = damping
    }

    /// Creates a spring descriptor with intuitive parameters.
    ///
    /// - Parameters:
    ///   - dampingRatio: The damping ratio of the spring. The value controls how "bouncy" the animation is, should be in the range of 0 to 1.
    ///     - 0: No damping, infinite oscillation
    ///     - 0.1-0.4: Very bouncy
    ///     - 0.5-0.8: Moderate bouncy
    ///     - 1.0: Critically damped (no oscillation, fastest approach)
    ///   - response: The response time of the spring. The value represents a time in seconds that approximates how long one complete oscillation would take in an undamped system.
    ///     - 0.2 - 0.4: Faster, more responsive animations
    ///     - 0.5 - 0.8: Moderate response
    ///     - 0.8 - 1.0: Slower, more damped animations
    ///     - 1.0 - 2.0: Very slow, very damped animations (like a heavy object)
    ///   - initialVelocity: The initial velocity of the object. Default is 0.
    public init(dampingRatio: CGFloat, response: CGFloat, initialVelocity: CGFloat = 0) {
        let dampingRatio = max(0, min(dampingRatio, 1))
        let response = max(0.01, response)

        self.initialVelocity = initialVelocity
        self.mass = 1
        self.stiffness = pow(2 * .pi / response, 2)
        self.damping = 4 * .pi * dampingRatio / response
    }

    /// Get the settling duration.
    public func settlingDuration() -> TimeInterval {
        makeTempAnimation().settlingDuration
    }

    /// Get the perceptual duration.
    public func perceptualDuration() -> TimeInterval {
        makeTempAnimation().perceptualDuration()
    }

    private func makeTempAnimation() -> CASpringAnimation {
        let animation = CASpringAnimation(keyPath: "position")
        animation.initialVelocity = initialVelocity

        animation.mass = mass
        animation.damping = damping
        animation.stiffness = stiffness

        animation.fromValue = 0
        animation.toValue = 100

        return animation
    }
}
