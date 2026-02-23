//
//  AnimationDelegate.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/25/21.
//

import Foundation
import QuartzCore

/// A `CAAnimation` delegate object.
///
/// `CAAnimation` strongly retain `delegate`, you can just assign the delegate without retaining it.
public final class AnimationDelegate: NSObject, CAAnimationDelegate {

    private let animationDidStart: ((_ animation: CAAnimation) -> Void)?
    private let animationDidStop: ((_ animation: CAAnimation, _ finished: Bool) -> Void)?

    private var didStart: Bool = false
    private var didStop: Bool = false

    /// Initialize a new `AnimationDelegate`.
    ///
    /// - Parameters:
    ///   - animationDidStart: The block to be called when the animation starts. It passes the animation as an argument.
    ///   - animationDidStop: The block to be called when the animation stops. It passes the animation and a boolean value indicating whether the animation finished as arguments.
    public init(animationDidStart: ((_ animation: CAAnimation) -> Void)? = nil,
                animationDidStop: ((_ animation: CAAnimation, _ finished: Bool) -> Void)? = nil)
    {
        self.animationDidStart = animationDidStart
        self.animationDidStop = animationDidStop
    }

    public func animationDidStart(_ animation: CAAnimation) {
        guard !didStart else {
            ComposeAssert.assertionFailure("animation already started: \(animation)")
            return
        }
        didStart = true
        animationDidStart?(animation)
    }

    public func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        guard !didStop else {
            ComposeAssert.assertionFailure("animation already stopped: \(animation)")
            return
        }
        didStop = true
        animationDidStop?(animation, finished)
    }
}
