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
      insert: options.contains(.insert) ? InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)

        let layer = renderable.layer
        if timing.delay > 0, !layer.hasInFlightOpacityAnimation {
          // a delayed fresh insertion shows the renderable before its animation starts, so hide it at the start value
          // for the delay window.
          layer.opacity = Float(from)
        }
        layer.retargetOpacity(
          freshStartValue: { _ in Float(from) },
          targetValue: Float(to),
          timing: timing,
          completion: completion
        )
      } : nil,
      remove: options.contains(.remove) ? RemoveTransition(
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
          renderable.layer.removeInFlightOpacityAnimations()
          renderable.layer.disableActions(for: "opacity") {
            renderable.layer.opacity = 1
          }
        }
      ) : nil
    )
  }
}

private extension CALayer {

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
  ///     evaluated when the animation actually starts. A retargeting that starts while an earlier one is still
  ///     waiting out its delay supersedes the earlier one.
  ///   - completion: The block called when the animation completes.
  func retargetOpacity(freshStartValue: @escaping (CALayer) -> Float,
                       targetValue: Float,
                       timing: AnimationTiming,
                       completion: @escaping () -> Void)
  {
    // a pending delayed retarget is superseded: if it fired later, it would tear down this retarget's animation
    // and complete this transition with stale values.
    cancelPendingOpacityRetarget()

    pendingOpacityRetarget = delay(timing.delay) { [weak self] in
      guard let self else {
        return
      }
      self.pendingOpacityRetarget = nil

      let interrupted = self.interruptedOpacityState()

      let start = interrupted?.value ?? freshStartValue(self)
      let delta = start - targetValue

      // the interrupted velocity carries over only through a spring's initial velocity.
      // Core Animation's convention: positive moves towards the target, in full distances per second.
      let initialVelocity: CGFloat?
      if let interrupted, case .spring = timing.timing, abs(delta) > 1e-3 {
        initialVelocity = CGFloat(-interrupted.velocity / Double(delta))
      } else {
        initialVelocity = nil
      }

      self.animate(
        keyPath: "opacity",
        timing: AnimationTiming(timing: timing.timing, delay: 0, speed: timing.speed),
        from: { _ in delta },
        to: { _ in 0 },
        model: { _ in targetValue },
        updateAnimation: {
          $0.isAdditive = true
          if let initialVelocity, let spring = $0 as? CASpringAnimation {
            spring.initialVelocity = initialVelocity
          }
          $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
            completion()
          })
        }
      )
    }
  }

  /// Whether the layer has an in-flight opacity animation.
  var hasInFlightOpacityAnimation: Bool {
    (animationKeys() ?? []).contains { key in
      (animation(forKey: key) as? CABasicAnimation)?.keyPath == "opacity"
    }
  }

  /// Evaluates and removes the in-flight opacity animations.
  ///
  /// The render pass owns a renderable layer's opacity through transitions, so every opacity animation on the layer is
  /// treated as an in-flight transition: additive animations contribute their evaluated value on top of the model value,
  /// and all of them are removed.
  ///
  /// - Returns: The composed opacity and its rate of change in opacity per second, or `nil` when no opacity animation
  ///   is in flight.
  func interruptedOpacityState() -> (value: Float, velocity: Double)? {
    let opacityAnimations = (animationKeys() ?? []).compactMap { key -> CABasicAnimation? in
      guard let animation = animation(forKey: key) as? CABasicAnimation, animation.keyPath == "opacity" else {
        return nil
      }
      return animation
    }
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

    removeInFlightOpacityAnimations()

    let clampedValue = max(0, min(value, 1))
    return (Float(clampedValue), (value - earlierValue) / velocitySamplingInterval)
  }

  /// Removes the in-flight opacity animations, leaving animations of other properties alone.
  func removeInFlightOpacityAnimations() {
    for key in animationKeys() ?? [] where (animation(forKey: key) as? CABasicAnimation)?.keyPath == "opacity" {
      removeAnimation(forKey: key)
    }
  }

  /// The timer of a delayed opacity retarget that hasn't started yet.
  var pendingOpacityRetarget: DispatchSourceTimer? {
    get {
      objc_getAssociatedObject(self, &pendingOpacityRetargetKey) as? DispatchSourceTimer
    }
    set {
      objc_setAssociatedObject(self, &pendingOpacityRetargetKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
  }

  /// Cancels the pending delayed opacity retarget, if any.
  func cancelPendingOpacityRetarget() {
    pendingOpacityRetarget?.cancel()
    pendingOpacityRetarget = nil
  }
}

private var pendingOpacityRetargetKey: UInt8 = 0
