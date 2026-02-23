//
//  CALayer+Animations.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
//

import QuartzCore
import UIKit

public extension CALayer {

    /// Animate the layer's frame additively.
    ///
    /// - Parameters:
    ///   - to: The frame to animate to.
    ///   - timing: The animation timing.
    func animateFrame(to: CGRect, timing: AnimationTiming) {
        animate(
            keyPath: "position",
            timing: timing,
            from: { $0.position - $0.position(from: to) },
            to: { _ in .zero },
            model: { $0.position(from: to) },
            updateAnimation: { $0.isAdditive = true }
        )
        animate(
            keyPath: "bounds.size",
            timing: timing,
            from: { $0.bounds.size - to.size },
            to: { _ in .zero },
            model: { _ in to.size },
            updateAnimation: { $0.isAdditive = true }
        )
    }

    /// Animate the layer's value additively.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to animate.
    ///   - to: The value to animate to.
    ///   - timing: The animation timing.
    ///   - updateAnimation: An optional closure to update the animation.
    func animate<T: FloatingPoint>(keyPath: String, to: T, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
        animate(
            keyPath: keyPath,
            timing: timing,
            from: { ($0.value(forKeyPath: keyPath) as! T) - to }, // swiftlint:disable:this force_cast
            to: { _ in 0 },
            model: { _ in to },
            updateAnimation: {
                $0.isAdditive = true
                updateAnimation?($0)
            }
        )
    }

    /// Animate the layer's value additively.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to animate.
    ///   - to: The value to animate to.
    ///   - timing: The animation timing.
    ///   - updateAnimation: An optional closure to update the animation.
    func animate(keyPath: String, to: CGSize, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
        animate(
            keyPath: keyPath,
            timing: timing,
            from: { ($0.value(forKeyPath: keyPath) as! CGSize) - to }, // swiftlint:disable:this force_cast
            to: { _ in .zero },
            model: { _ in to },
            updateAnimation: {
                $0.isAdditive = true
                updateAnimation?($0)
            }
        )
    }

    /// Animate the layer's value additively.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to animate.
    ///   - to: The value to animate to.
    ///   - timing: The animation timing.
    ///   - updateAnimation: An optional closure to update the animation.
    func animate(keyPath: String, to: CGPoint, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
        animate(
            keyPath: keyPath,
            timing: timing,
            from: { ($0.value(forKeyPath: keyPath) as! CGPoint) - to }, // swiftlint:disable:this force_cast
            to: { _ in .zero },
            model: { _ in to },
            updateAnimation: {
                $0.isAdditive = true
                updateAnimation?($0)
            }
        )
    }

    /// Add an animation to the layer.
    ///
    /// - Important: You must make sure the value type matches the key path type.
    ///
    /// - Parameters:
    ///   - key: The key to use for the animation. If `nil`, the key path will be used.
    ///   - keyPath: The key path to animate.
    ///   - timing: The animation timing.
    ///   - from: The value to animate from.
    ///   - to: The value to animate to.
    ///   - model: The model value to set. If `nil`, the `to` value will be used.
    ///   - updateAnimation: An optional closure to update the animation.
    func animate<T>(key: String? = nil,
                    keyPath: String,
                    timing: AnimationTiming,
                    from: @escaping (CALayer) -> T,
                    to: @escaping (CALayer) -> T,
                    model: ((CALayer) -> T)? = nil,
                    updateAnimation: ((CABasicAnimation) -> Void)? = nil)
    {
        delay(timing.delay) { [weak self] in
            guard let self = self else {
                return
            }

            let model = model ?? to

            guard timing.timing.duration > 0 else {
                self.setKeyPathValue(keyPath, model(self))
                return
            }

            let animation = CABasicAnimation.makeAnimation(timing)
            animation.keyPath = keyPath
            animation.fromValue = from(self)
            animation.toValue = to(self)

            updateAnimation?(animation)

            let rawKey = key ?? keyPath
            let key: String
            if animation.isAdditive {
                key = self.uniqueAnimationKey(key: rawKey)
            } else {
                key = rawKey
            }
            self.add(animation, forKey: key)

            self.setKeyPathValue(keyPath, model(self))
        }
    }

    func setKeyPathValue(_ keyPath: String, _ value: Any) {
        if keyPath == "opacity", let backedView {
            CATransaction.disableAnimations {
                let newValue = value as! Float // swiftlint:disable:this force_cast
                backedView.alpha = CGFloat(newValue)
                opacity = newValue
            }
            ComposeAssert.assert(CGFloat(opacity) == backedView.alpha)
            return
        }

        CATransaction.disableAnimations {
            setValue(value, forKeyPath: keyPath)
        }
    }

    /// Get a unique animation key.
    ///
    /// This is useful when you want to add multiple animations, such as additive animations, with the same name to a layer.
    ///
    /// For example, if the animation for "position" already exists, the function will return "position-1".
    ///
    /// - Parameters:
    ///   - key: The desired animation key.
    /// - Returns: A unique animation key.
    func uniqueAnimationKey(key: String) -> String {
        var currentKey = key
        var counter = 1

        while animation(forKey: currentKey) != nil {
            currentKey = "\(key)-\(counter)"
            counter += 1
        }

        return currentKey
    }

    /// The layer's backed view if it is a backing layer for a view.
    ///
    /// On Mac, for layer-backed views, setting the layer's frame won't affect the backed view's frame.
    /// Use this property to find the backed view if you want to manipulate the view's frame.
    @inlinable
    @inline(__always)
    var backedView: UIView? {
        delegate as? UIView
    }
}

private extension CGSize {

    static func - (left: CGSize, right: CGSize) -> CGSize {
        CGSize(width: left.width - right.width, height: left.height - right.height)
    }
}
