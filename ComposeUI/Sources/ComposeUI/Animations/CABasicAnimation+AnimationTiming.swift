//
//  CABasicAnimation+AnimationTiming.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/25/21.
//

import Foundation
import QuartzCore

public extension CABasicAnimation {

    /// Make an animation based on the timing.
    ///
    /// - Parameters:
    ///   - timing: The timing of the animation.
    /// - Returns: The animation.
    static func makeAnimation(_ timing: AnimationTiming) -> CABasicAnimation {
        let animation: CABasicAnimation
        switch timing.timing {
        case .spring(let spring, let duration):
            let springAnimation = CASpringAnimation()
            springAnimation.initialVelocity = spring.initialVelocity

            springAnimation.mass = spring.mass
            springAnimation.damping = spring.damping
            springAnimation.stiffness = spring.stiffness

            // without setting the duration, the spring animation can abruptly stop before the completion
            springAnimation.duration = duration ?? springAnimation.perceptualDuration()
            animation = springAnimation

        case .timingFunction(let duration, let timingFunction):
            animation = CABasicAnimation()
            animation.timingFunction = timingFunction
            animation.duration = duration
        }

        animation.speed = Float(timing.speed)
        animation.fillMode = .both // avoid the final frame appears before the animation

        return animation
    }
}
