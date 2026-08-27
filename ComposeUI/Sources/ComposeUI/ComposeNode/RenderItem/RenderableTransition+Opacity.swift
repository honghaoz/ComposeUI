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

        let layer = renderable.layer
        if timing.delay > 0, layer.basicAnimations(forKeyPath: "opacity").isEmpty {
          // a delayed fresh insertion shows the renderable before its animation starts, so hide it at the start value
          // for the delay window.
          layer.setKeyPathValue("opacity", Float(from))
        }
        layer.retargetOpacity(
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
          renderable.layer.cancelPendingOpacityRetarget()
          renderable.layer.setKeyPathValue("opacity", Float(1))
        }
      ) : nil
    )
  }
}

private extension AnimationTiming {

  /// The timing for a retargeting animation.
  ///
  /// The retargeting animation uses the same curve without the delay, because the retargeting itself absorbs the delay.
  /// For a spring timing, the interrupted velocity is carried into the spring's initial velocity, in Core Animation's
  /// convention (positive moves towards the target, in full from-to distances per second), so the spring's derived
  /// duration accounts for the carried velocity.
  ///
  /// The velocity is dropped for a tiny from-to distance: the normalized velocity diverges as the distance approaches
  /// zero, and continuing a sub-1% opacity distance with momentum is imperceptible anyway.
  ///
  /// - Parameters:
  ///   - velocity: The interrupted rate of change, in value units per second. `nil` when nothing was interrupted.
  ///   - delta: The retargeting animation's from-to distance, in value units.
  /// - Returns: The retarget timing.
  func retargeted(carryingVelocity velocity: Double?, over delta: Float) -> AnimationTiming {
    let retargetTiming: Timing
    switch timing {
    case .spring(let descriptor, let duration):
      if let velocity, abs(delta) > 0.01, speed > 0 {
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
    return AnimationTiming(timing: retargetTiming, delay: 0, speed: speed)
  }
}

private extension CALayer {

  private static var pendingOpacityRetargetKey: UInt8 = 0

  /// The timer of a delayed opacity retarget that hasn't started yet.
  var pendingOpacityRetarget: DispatchSourceTimer? {
    get {
      objc_getAssociatedObject(self, &CALayer.pendingOpacityRetargetKey) as? DispatchSourceTimer
    }
    set {
      objc_setAssociatedObject(self, &CALayer.pendingOpacityRetargetKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
  }

  /// Replaces any in-flight opacity animations with a single additive animation towards `targetValue`.
  ///
  /// When in-flight opacity animations exist, the new animation continues from the opacity they currently show.
  /// For a spring timing, it also continues with their current velocity, through the spring's initial velocity.
  /// Without in-flight animations, the new animation starts from `freshStartValue`.
  ///
  /// - Parameters:
  ///   - freshStartValue: The opacity to start from when no opacity animation is in flight. Evaluated when the
  ///     animation actually starts, after the timing's delay.
  ///   - targetValue: The opacity to animate to. Also set as the model value.
  ///   - timing: The timing for the animation. The delay defers the retargeting itself, so the interrupted state is
  ///     evaluated when the animation actually starts. A retargeting that starts while an earlier one is still waiting
  ///     out its delay supersedes the earlier one.
  ///   - completion: The block called when the animation completes.
  func retargetOpacity(freshStartValue: @escaping (CALayer) -> Float,
                       targetValue: Float,
                       timing: AnimationTiming,
                       completion: @escaping () -> Void)
  {
    // a pending delayed retarget is superseded: if it fired later, it would tear down this retarget's animation and
    // complete this transition with stale values.
    cancelPendingOpacityRetarget()

    pendingOpacityRetarget = delay(timing.delay) { [weak self] in
      guard let self else {
        return
      }
      self.pendingOpacityRetarget = nil

      let interrupted = self.interruptedOpacityState()
      self.removeAnimations(forKeyPath: "opacity")

      let start = interrupted?.value ?? freshStartValue(self)
      let delta = start - targetValue

      self.animate(
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
  }

  /// Evaluates the in-flight opacity animations.
  ///
  /// The transition owns the renderable layer's opacity, so every opacity animation on the layer is treated as an
  /// in-flight transition: additive animations contribute their evaluated value on top of the model value.
  ///
  /// - Returns: The composed opacity and its rate of change in opacity per second, or `nil` when no opacity animation
  ///   is in flight.
  func interruptedOpacityState() -> (value: Float, velocity: Double)? {
    let opacityAnimations = basicAnimations(forKeyPath: "opacity")
    guard !opacityAnimations.isEmpty else {
      return nil
    }

    let now = convertTime(CACurrentMediaTime(), from: nil)
    let velocitySamplingInterval: TimeInterval = 1 / 240

    var value = Double(opacity)
    var earlierValue = Double(opacity)
    for animation in opacityAnimations where animation.isAdditive {
      value += animation.scalarValue(at: now) ?? 0
      earlierValue += animation.scalarValue(at: now - velocitySamplingInterval) ?? 0
    }

    let clampedValue = max(0, min(value, 1))
    return (Float(clampedValue), (value - earlierValue) / velocitySamplingInterval)
  }

  /// Cancels the pending delayed opacity retarget, if any.
  func cancelPendingOpacityRetarget() {
    pendingOpacityRetarget?.cancel()
    pendingOpacityRetarget = nil
  }
}
