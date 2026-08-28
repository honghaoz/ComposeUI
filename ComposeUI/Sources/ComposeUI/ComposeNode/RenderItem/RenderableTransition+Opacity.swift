//
//  RenderableTransition+Opacity.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/18/24.
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

public extension RenderableTransition {

  /// Creates an opacity transition.
  ///
  /// The transition keeps a single opacity animation on the renderable: starting a transition while another one is in
  /// flight replaces the in-flight animation with one that continues from the current visual opacity (and, for spring
  /// timings, the current velocity).
  /// Stacking is not an option for opacity because the render server clamps opacity per animation while compositing
  /// additive animations, so opposing stacked animations do not compose (the screen diverges from the unclamped sum
  /// that `presentation()` reports).
  ///
  /// - Parameters:
  ///   - from: The starting opacity value.
  ///   - to: The ending opacity value.
  ///   - timing: The timing function for the animation.
  ///   - options: The options for the transition.
  static func opacity(from: CGFloat = 0,
                      to: CGFloat = 1,
                      timing: AnimationTiming = .easeInEaseOut(duration: Animations.defaultAnimationDuration),
                      options: RenderableTransition.Options = .both) -> RenderableTransition
  {
    RenderableTransition(
      insert: options.contains(.insert) ? InsertTransition(takesOverKeyPaths: ["opacity"]) { renderable, context, completion in
        renderable.setFrame(context.targetFrame)

        renderable.layer.retargetOpacity(
          freshStartValue: { _ in Float(from) },
          targetValue: Float(to),
          timing: timing,
          completion: completion
        )
      } : nil,
      remove: options.contains(.remove) ? RemoveTransition(
        animatedKeyPaths: ["opacity"],
        animate: { renderable, _, completion in
          renderable.layer.retargetOpacity(
            freshStartValue: { $0.opacity },
            targetValue: Float(from),
            timing: timing,
            completion: completion
          )
        },
        resetForReuse: { renderable in
          renderable.layer.setKeyPathValue("opacity", Float(1))
        }
      ) : nil
    )
  }
}

private extension AnimationTiming {

  /// The timing for a retargeting animation.
  ///
  /// For a spring timing, the interrupted velocity is carried into the spring's initial velocity, in Core Animation's
  /// convention (positive moves towards the target, in full from-to distances per second), so the spring's derived
  /// duration accounts for the carried velocity.
  ///
  /// The velocity is only carried by an immediate retargeting: a delayed one freezes the interrupted motion at rest
  /// for the delay window, so its spring launches from rest. The velocity is also dropped for a from-to distance
  /// below `RetargetConstants.velocityCarryMinimumDelta`.
  ///
  /// - Parameters:
  ///   - velocity: The interrupted rate of change, in value units per second. `nil` when nothing was interrupted.
  ///   - delta: The retargeting animation's from-to distance, in value units.
  /// - Returns: The retarget timing.
  func retargeted(carryingVelocity velocity: Double?, over delta: Float) -> AnimationTiming {
    let retargetTiming: Timing
    switch timing {
    case .spring(let descriptor, let duration):
      if let velocity, delay == 0, abs(delta) > RetargetConstants.velocityCarryMinimumDelta, speed > 0 {
        let initialVelocity = CGFloat(-velocity) / (CGFloat(delta) * speed)
        let descriptor = SpringDescriptor(
          initialVelocity: initialVelocity,
          mass: descriptor.mass,
          stiffness: descriptor.stiffness,
          damping: descriptor.damping
        )
        retargetTiming = .spring(descriptor, duration: duration)
      } else {
        retargetTiming = timing
      }
    case .timingFunction:
      retargetTiming = timing
    }
    return AnimationTiming(timing: retargetTiming, delay: delay, speed: speed)
  }
}

private extension CALayer {

  /// Replaces any in-flight opacity animations with a single additive animation towards `targetValue`.
  ///
  /// When an opacity transition is in flight (running animations, or a scheduled one whose delay hasn't elapsed),
  /// the new animation continues from the opacity the layer currently shows. For a spring timing, it also continues
  /// with the current velocity, through the spring's initial velocity. Without an in-flight transition, the new
  /// animation starts from `freshStartValue`.
  ///
  /// The timing's delay schedules the new animation's begin time: the interrupted state is evaluated when the
  /// retargeting is dispatched, and the animation holds its start value until the delay elapses, so an interrupted
  /// in-flight animation freezes at its sampled value for the delay window.
  ///
  /// A zero-duration timing applies `targetValue` and completes immediately when there is no delay. With a delay,
  /// the change is scheduled as a snap that applies right after the delay window.
  ///
  /// - Parameters:
  ///   - freshStartValue: The opacity to start from when no opacity transition is in flight.
  ///   - targetValue: The opacity to animate to. Also set as the model value.
  ///   - timing: The timing for the animation.
  ///   - completion: The block called when the animation completes.
  func retargetOpacity(freshStartValue: @escaping (CALayer) -> Float,
                       targetValue: Float,
                       timing: AnimationTiming,
                       completion: @escaping () -> Void)
  {
    let interrupted = interruptedOpacityState()
    removeAnimations(forKeyPath: "opacity")

    guard timing.timing.duration > 0 || timing.delay > 0 else {
      setKeyPathValue("opacity", targetValue)
      completion()
      return
    }

    let start = interrupted?.value ?? freshStartValue(self)
    let delta = start - targetValue

    animate(
      keyPath: "opacity",
      timing: timing.retargeted(carryingVelocity: interrupted?.velocity, over: delta),
      from: { _ in delta },
      to: { _ in 0 },
      model: { _ in targetValue },
      updateAnimation: {
        $0.isAdditive = true
        $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
          completion()
        })
      }
    )
  }

  /// Evaluates the in-flight opacity animations.
  ///
  /// The transition owns the renderable layer's opacity, so every opacity animation on the layer is treated as an
  /// in-flight transition. The animations compose in their key order, the same way Core Animation applies them: a
  /// non-additive animation replaces the composed value, and an additive animation contributes on top of it. A
  /// scheduled animation whose delay hasn't elapsed contributes the start value its fill mode is holding.
  ///
  /// - Returns: The composed opacity and its rate of change in opacity per second, or `nil` when no opacity animation
  ///   is in flight. The value is clamped to opacity's rendered [0, 1] range, and the rate is zero when it would push
  ///   past a saturated bound, because motion past a bound isn't visible and carries no momentum.
  func interruptedOpacityState() -> (value: Float, velocity: Double)? {
    let opacityAnimations = basicAnimations(forKeyPath: "opacity")
    guard !opacityAnimations.isEmpty else {
      return nil
    }

    let now = convertTime(CACurrentMediaTime(), from: nil)

    func composedValue(at time: TimeInterval) -> Double {
      var value = Double(opacity)
      for animation in opacityAnimations {
        guard let animationValue = animation.scalarValue(at: time) else {
          ComposeUI.assertFailure("unsupported in-flight opacity animation: \(animation)")
          continue
        }
        if animation.isAdditive {
          value += animationValue
        } else {
          value = animationValue
        }
      }
      return value
    }

    let value = composedValue(at: now)
    let earlierValue = composedValue(at: now - RetargetConstants.velocitySamplingInterval)

    let clampedValue = max(0, min(value, 1))
    var velocity = (value - earlierValue) / RetargetConstants.velocitySamplingInterval
    if (clampedValue == 0 && velocity < 0) || (clampedValue == 1 && velocity > 0) {
      velocity = 0
    }
    return (Float(clampedValue), velocity)
  }
}

private enum RetargetConstants {

  /// The minimum from-to distance for carrying the interrupted velocity into a spring retarget.
  ///
  /// The normalized velocity diverges as the distance approaches zero, and continuing a sub-1% opacity distance with
  /// momentum is imperceptible anyway.
  static let velocityCarryMinimumDelta: Float = 0.01

  /// The finite-difference interval for sampling the interrupted rate of change.
  static let velocitySamplingInterval: TimeInterval = 1 / 240
}
