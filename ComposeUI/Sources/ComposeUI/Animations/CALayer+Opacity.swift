//
//  CALayer+Opacity.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/25/26.
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

public extension CALayer {

  /// Animates the opacity to a value with one animation that continues from the opacity the layer shows.
  ///
  /// With opacity animations in flight, the new animation continues from the opacity the layer currently shows. The
  /// in-flight opacity animations are replaced, not stacked on, since the render server clamps opacity after each
  /// animation, additive animations don't compose well. For a spring timing, it also continues with the current velocity.
  /// A delayed animation holds the shown opacity until it starts.
  ///
  /// Without in-flight opacity animations, the new animation starts from `freshStartValue`.
  ///
  /// - Parameters:
  ///   - targetValue: The opacity to animate to, also set as the model value.
  ///   - timing: The animation timing. A zero duration sets the value right away, or after the delay.
  ///   - freshStartValue: The opacity to start from when nothing is in flight. `nil` starts from the model value.
  ///   - completion: Called when the animation finishes or is removed early.
  @_spi(Private)
  func animateOpacity(to targetValue: Float,
                      timing: AnimationTiming,
                      freshStartValue: Float? = nil,
                      completion: (() -> Void)? = nil)
  {
    animateOpacity(
      to: targetValue,
      timing: timing,
      freshStartValue: freshStartValue,
      completion: completion,
      replacing: keyedPropertyAnimations(forKeyPath: "opacity")
    )
  }

  /// Animates the opacity, see `animateOpacity(to:timing:freshStartValue:completion:)`, replacing the layer's opacity
  /// animations, which the caller has read.
  ///
  /// - Parameters:
  ///   - targetValue: The opacity to animate to, also set as the model value.
  ///   - timing: The animation timing.
  ///   - freshStartValue: The opacity to start from when nothing is in flight. `nil` starts from the model value.
  ///   - completion: Called when the animation finishes or is removed early.
  ///   - opacityAnimations: The layer's opacity animations and their keys, see `keyedPropertyAnimations(forKeyPath:)`.
  private func animateOpacity(to targetValue: Float,
                              timing: AnimationTiming,
                              freshStartValue: Float?,
                              completion: (() -> Void)?,
                              replacing opacityAnimations: InlineFirstArray<(key: String, animation: CAPropertyAnimation)>)
  {
    let interrupted = interruptedOpacityState(of: opacityAnimations)
    for (key, _) in opacityAnimations {
      removeAnimation(forKey: key)
    }

    guard timing.timing.duration > 0 || timing.delay > 0 else {
      setKeyPathValue("opacity", targetValue)
      completion?()
      return
    }

    let start = interrupted?.value ?? freshStartValue ?? opacity
    let delta = start - targetValue

    animate(
      keyPath: "opacity",
      timing: timing.retargeted(carryingVelocity: interrupted?.velocity, over: delta),
      from: { _ in delta },
      to: { _ in 0 },
      model: { _ in targetValue },
      updateAnimation: {
        $0.isAdditive = true
        if let interrupted {
          // the layer shows the replaced motion until the animation begins, see `interruptedOpacityState()`
          $0.setValue(interrupted.value, forKey: RetargetConstants.replacedOpacityKey)
          $0.setValue(interrupted.velocity, forKey: RetargetConstants.replacedVelocityKey)
        }
        if let completion {
          $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
            completion()
          })
        }
      }
    )
  }

  /// Sets the opacity and continues the in-flight opacity animations toward it, like `retarget(keyPath:to:)`.
  ///
  /// The glide starts from the computed shown opacity instead of `presentation()`, which is `nil` before the layer is
  /// committed, so a later opacity animation can continue from it.
  ///
  /// - Parameter value: The opacity to set.
  @_spi(Private)
  func retargetOpacity(to value: Float) {
    // the in-flight animations already head to the value
    guard opacity != value else {
      return
    }

    // without opacity animations, the current time isn't read, since reading it converts the time through the layer tree
    let opacityAnimations = keyedPropertyAnimations(forKeyPath: "opacity")
    guard !opacityAnimations.isEmpty else {
      setKeyPathValue("opacity", value)
      return
    }

    let now = currentTime
    var remainingTime: TimeInterval?
    var neverFinishes = false
    for (_, animation) in opacityAnimations {
      guard let animationRemainingTime = animation.remainingTime(at: now) else {
        continue
      }
      remainingTime = max(remainingTime ?? 0, animationRemainingTime)
      neverFinishes = neverFinishes || CAAnimation.neverFinishes(duration: animation.duration)
    }

    guard let remainingTime else {
      setKeyPathValue("opacity", value)
      return
    }

    // an animation that never finishes has no end to land with, so the glide takes the default duration
    animateOpacity(
      to: value,
      timing: .easeOut(duration: neverFinishes ? Animations.defaultAnimationDuration : remainingTime),
      freshStartValue: nil,
      completion: nil,
      replacing: opacityAnimations
    )
  }
}

extension CALayer {

  /// The opacity the in-flight opacity animations show and its rate of change per second.
  ///
  /// The animations are evaluated from their begin times at the current time of the animation clock, see `AnimationClock`.
  /// An animation `animateOpacity` added at the current time hasn't moved yet, so the layer still shows the motion it
  /// replaced, and this returns that motion's opacity and rate.
  ///
  /// - Returns: The opacity, clamped to [0, 1] after each animation like the render server does, and its rate, zero
  ///   when it pushes past a bound. `nil` when no opacity animation is in flight.
  func interruptedOpacityState() -> (value: Float, velocity: Double)? {
    interruptedOpacityState(of: keyedPropertyAnimations(forKeyPath: "opacity"))
  }

  /// The opacity the given opacity animations show and its rate of change per second, see `interruptedOpacityState()`.
  ///
  /// - Parameter opacityAnimations: The layer's opacity animations and their keys, see
  ///   `keyedPropertyAnimations(forKeyPath:)`.
  /// - Returns: The opacity and its rate, see `interruptedOpacityState()`. `nil` without opacity animations.
  private func interruptedOpacityState(of opacityAnimations: InlineFirstArray<(key: String, animation: CAPropertyAnimation)>) -> (value: Float, velocity: Double)? {
    guard !opacityAnimations.isEmpty else {
      return nil
    }

    let now = currentTime

    // an animation added at the current time begins now, so the layer still shows the motion it replaced
    if opacityAnimations.count == 1,
       opacityAnimations[0].animation.beginTime == CAAnimation.beginTime(at: now),
       let replacedOpacity = opacityAnimations[0].animation.value(forKey: RetargetConstants.replacedOpacityKey) as? Float,
       let replacedVelocity = opacityAnimations[0].animation.value(forKey: RetargetConstants.replacedVelocityKey) as? Double
    {
      return (replacedOpacity, replacedVelocity)
    }

    func composedValue(at time: TimeInterval) -> Double {
      var value = Double(opacity)
      for (_, animation) in opacityAnimations {
        guard let animationValue = (animation as? CABasicAnimation)?.scalarValue(at: time) else {
          ComposeUI.assertFailure("unsupported in-flight opacity animation: \(animation)")
          continue
        }
        if animation.isAdditive {
          value += animationValue
        } else {
          value = animationValue
        }
        // the render server clamps opacity after each animation
        value = max(0, min(value, 1))
      }
      return value
    }

    // the rate is measured over the sampling interval back from now, but not from before an animation began in it: an
    // animation holds its from value until it begins, and measuring across the begin would mix the hold into its rate.
    // an unset begin time, zero, isn't a begin in the interval, as the animation hasn't begun
    var samplingStart = now - RetargetConstants.velocitySamplingInterval
    for (_, animation) in opacityAnimations where animation.beginTime != 0 && animation.beginTime < now {
      samplingStart = max(samplingStart, animation.beginTime)
    }

    let value = composedValue(at: now)
    let earlierValue = composedValue(at: samplingStart)

    var velocity = (value - earlierValue) / (now - samplingStart)
    if (value == 0 && velocity < 0) || (value == 1 && velocity > 0) {
      velocity = 0
    }
    return (Float(value), velocity)
  }
}

private extension AnimationTiming {

  /// The timing with the in-flight velocity carried into a spring.
  ///
  /// A delayed animation starts from rest, so it carries no velocity, and neither does a tiny distance.
  ///
  /// - Parameters:
  ///   - velocity: The in-flight rate of change per second. `nil` when nothing was in flight.
  ///   - delta: The distance the new animation covers.
  /// - Returns: The timing.
  func retargeted(carryingVelocity velocity: Double?, over delta: Float) -> AnimationTiming {
    let retargetTiming: Timing
    switch timing {
    case .spring(let descriptor, let duration):
      if let velocity, delay <= 0, abs(delta) > RetargetConstants.velocityCarryMinimumDelta, speed > 0 {
        // Core Animation's initial velocity is in distances per second, positive toward the target
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

private enum RetargetConstants {

  /// The smallest distance that carries the in-flight velocity. Below it, the velocity per distance blows up, and the
  /// motion is too small to see.
  static let velocityCarryMinimumDelta: Float = 0.01

  /// The interval for sampling the in-flight rate of change.
  static let velocitySamplingInterval: TimeInterval = 1 / 240

  /// The key of the opacity an opacity animation replaced, kept on the animation.
  static let replacedOpacityKey = "ComposeUI.replacedOpacity"

  /// The key of the rate of change an opacity animation replaced, kept on the animation.
  static let replacedVelocityKey = "ComposeUI.replacedOpacityVelocity"
}
