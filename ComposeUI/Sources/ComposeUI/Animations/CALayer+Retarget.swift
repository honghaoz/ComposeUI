//
//  CALayer+Retarget.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/21/26.
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

  /// Sets a key path's value and retargets its in-flight animations to it, so the motion continues from where it is
  /// and lands on the new value when it would have.
  ///
  /// - Without in-flight animations, the value is set directly. An animation already heading to the value is left alone.
  ///   An ended animation still on the layer is removed, since a forwards fill would show its end value over the new one.
  /// - Additive animations of numbers, `CGSize` and `CGPoint` are kept, with a scaled copy of each stacked on top that
  ///   cancels the jump and fades along the animation's own curve. When the remaining motion can't be scaled, one
  ///   ease-out correction is stacked instead.
  /// - Non-additive animations are replaced by one ease-out animation from the shown value over the remaining time.
  ///   Note that additive animations of `opacity` and `shadowOpacity` are also treated as non-additive, since the
  ///   render server clamps them after each animation and stacked animations wouldn't compose on screen.
  ///
  /// - Important: The value's type must match the key path's, or Core Animation crashes.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to set.
  ///   - value: The value to set.
  func retarget(keyPath: String, to value: Any) {
    let now = currentTime
    removeEndedAnimations(forKeyPath: keyPath, at: now)
    let inFlightAnimations = inFlightAnimations(forKeyPath: keyPath, at: now)
    guard let remainingTime = inFlightAnimations.map(\.remainingTime).max() else {
      // no in-flight animations, set the value directly
      setKeyPathValue(keyPath, value)
      return
    }

    // an in-flight animation already heading to the value keeps its easing, skipping the retarget
    let currentValue = self.value(forKeyPath: keyPath)
    if let currentValue, (currentValue as AnyObject).isEqual(value) {
      return
    }

    // uses the basic easing curve for simplicity, no interrupted velocity to carry
    let timing = AnimationTiming.easeOut(duration: remainingTime)

    if !Constants.clampedKeyPaths.contains(keyPath),
       inFlightAnimations.allSatisfy(\.animation.isAdditive),
       let currentValue,
       let oldValue = AdditiveValue(currentValue),
       let newValue = AdditiveValue(value),
       oldValue.isSameKind(as: newValue),
       let additiveAnimations = inFlightAdditiveAnimations(of: inFlightAnimations.map { ($0.key, $0.animation) }, ofKind: oldValue, at: now)
    {
      // the additive animations keep going and land on the new model value on their own. the model change would show as
      // a jump of `old - new`, so correction animations that add up to it now and fade with the animations are stacked on top
      let jump = oldValue - newValue
      if let factors = correctionFactors(for: additiveAnimations, cancelling: jump, at: now, over: remainingTime) {
        stackCorrectionAnimations(on: additiveAnimations, scaledBy: factors, forKeyPath: keyPath)
        setKeyPathValue(keyPath, value)
      } else {
        // no motion to scale, so one correction animation eases out on its own
        animate(
          keyPath: keyPath,
          timing: timing,
          from: { _ in jump.value },
          to: { _ in jump.zero.value },
          model: { _ in value },
          updateAnimation: {
            $0.isAdditive = true
            $0.setValue(true, forKey: Constants.correctionTag)
          }
        )
      }
    } else {
      // remove the in-flight animations and replace them with a new one from the current value to the new value
      removeAnimations(forKeyPath: keyPath)
      animate(
        keyPath: keyPath,
        timing: timing,
        from: { $0.presentation()?.value(forKeyPath: keyPath) },
        to: { _ -> Any? in value }
      )
    }
  }

  /// The time the layer's in-flight animations of the given key path have left, in seconds of the layer's time space.
  ///
  /// The time is the longest animation's: a delayed animation that hasn't begun counts its remaining delay, and an
  /// animation whose `beginTime` is still unset (zero) begins when the transaction commits, so it counts its full
  /// duration. A paused animation (zero speed) counts its duration, as it has no end to measure to.
  ///
  /// - Parameter keyPath: The animated key path.
  /// - Returns: The remaining time, or `nil` when no animation of the key path is in flight.
  internal func remainingAnimationTime(forKeyPath keyPath: String) -> TimeInterval? {
    inFlightAnimations(forKeyPath: keyPath, at: currentTime).map(\.remainingTime).max()
  }

  /// The layer's property animations of the given key path that haven't ended at `now`, with their keys and the time
  /// each has left.
  private func inFlightAnimations(forKeyPath keyPath: String, at now: TimeInterval) -> [(key: String, animation: CAPropertyAnimation, remainingTime: TimeInterval)] {
    (animationKeys() ?? []).compactMap { key in
      guard let animation = animation(forKey: key) as? CAPropertyAnimation,
            animation.keyPath == keyPath,
            let remainingTime = remainingTime(of: animation, at: now)
      else {
        return nil
      }
      return (key, animation, remainingTime)
    }
  }

  /// Removes the layer's property animations of the given key path that have ended at `now`.
  ///
  /// An ended animation is normally removed by Core Animation. One kept with `isRemovedOnCompletion` off and a forwards
  /// fill still shows its end value over the model value, so it has to go for a new model value to show.
  private func removeEndedAnimations(forKeyPath keyPath: String, at now: TimeInterval) {
    for key in animationKeys() ?? [] {
      guard let animation = animation(forKey: key) as? CAPropertyAnimation,
            animation.keyPath == keyPath,
            remainingTime(of: animation, at: now) == nil
      else {
        continue
      }
      removeAnimation(forKey: key)
    }
  }

  /// The time an animation has left at `now`, or `nil` when it has ended.
  private func remainingTime(of animation: CAAnimation, at now: TimeInterval) -> TimeInterval? {
    let scaledDuration = animation.speed > 0 ? animation.duration / TimeInterval(animation.speed) : animation.duration
    let remainingTime = animation.beginTime == 0 ? scaledDuration : animation.beginTime + scaledDuration - now
    return remainingTime > 0 ? remainingTime : nil
  }

  /// An in-flight additive animation of the retargeted key path: a basic animation from an offset to zero.
  private struct InFlightAdditiveAnimation {

    /// The animation's key on the layer.
    let key: String

    let animation: CABasicAnimation

    /// The offset the animation starts from, its `fromValue`, which shrinks to zero as it ends.
    let offset: AdditiveValue
  }

  /// The in-flight additive animations of one key path, when every one of them is a basic animation from an offset of
  /// `kind` to zero.
  ///
  /// The remaining motion is computed the way `progress(forElapsedTime:)` evaluates an animation, which doesn't cover
  /// repeats and time offsets. A scheduled animation is taken to hold its offset until it begins, which takes a
  /// backwards fill. An animation ending on a non-zero offset doesn't land on the model value.
  ///
  /// - Parameters:
  ///   - animations: The in-flight additive animations with their keys.
  ///   - kind: A value of the key path's kind.
  ///   - now: The layer's current time.
  /// - Returns: The animations, or `nil` when one of them isn't such an animation.
  private func inFlightAdditiveAnimations(of animations: [(key: String, animation: CAPropertyAnimation)], ofKind kind: AdditiveValue, at now: TimeInterval) -> [InFlightAdditiveAnimation]? {
    var additiveAnimations: [InFlightAdditiveAnimation] = []
    for (key, animation) in animations {
      guard let animation = animation as? CABasicAnimation,
            animation.byValue == nil,
            animation.repeatCount == 0,
            animation.repeatDuration == 0,
            !animation.autoreverses,
            animation.timeOffset == 0,
            animation.beginTime <= now || animation.fillMode == .backwards || animation.fillMode == .both,
            let offset = animation.fromValue.flatMap({ AdditiveValue($0) }),
            offset.isSameKind(as: kind),
            let endOffset = animation.toValue.flatMap({ AdditiveValue($0) }),
            endOffset.isSameKind(as: kind),
            endOffset.isZero
      else {
        return nil
      }
      additiveAnimations.append(InFlightAdditiveAnimation(key: key, animation: animation, offset: offset))
    }
    return additiveAnimations
  }

  /// The factors that scale the animations' remaining motion to `jump`, per component.
  ///
  /// A copy of each animation scaled by them adds up to the jump at `now` and to zero when the animations end, fading
  /// exactly as the animations deliver the motion they have left. Stacked on the animations, the copies turn the jump
  /// into a glide along that motion.
  ///
  /// - Parameters:
  ///   - animations: The in-flight additive animations of one key path, see `inFlightAdditiveAnimations(of:ofKind:at:)`.
  ///   - jump: The value the copies add up to at `now`, of the animations' kind.
  ///   - now: The layer's current time.
  ///   - remainingTime: The time the animations have left.
  /// - Returns: The factors, or `nil` when the animations' remaining motion can't be scaled to the jump: a component of
  ///   the jump has no motion left to scale, or the motion grows again before it ends (a spring about to swing back),
  ///   which the scaling would amplify.
  private func correctionFactors(for animations: [InFlightAdditiveAnimation],
                                 cancelling jump: AdditiveValue,
                                 at now: TimeInterval,
                                 over remainingTime: TimeInterval) -> [CGFloat]?
  {
    // the motion the animations have left at a time: what they still add to the model value
    func remainingMotion(at time: TimeInterval) -> AdditiveValue {
      animations.reduce(jump.zero) { motion, additiveAnimation in
        let animation = additiveAnimation.animation
        // an unset begin time resolves to the next commit, so the animation is taken to begin now
        let beginTime = animation.beginTime == 0 ? now : animation.beginTime
        let progress = animation.progress(forElapsedTime: (time - beginTime) * TimeInterval(animation.speed))
        return motion + additiveAnimation.offset.scaled(by: 1 - CGFloat(progress))
      }
    }

    // a copy scaled to the jump also scales everything the motion does later, so the motion has to shrink from here:
    // it is sampled to its end to check, since a spring can swing back out
    let motionNow = remainingMotion(at: now)
    let sampledDuration = min(remainingTime, TimeInterval(Constants.maxMotionSamples) / Constants.motionSamplesPerSecond)
    let sampleCount = max(2, Int((sampledDuration * Constants.motionSamplesPerSecond).rounded(.up)))
    var peakMotion = motionNow.magnitudes
    for index in 1 ... sampleCount {
      let motion = remainingMotion(at: now + remainingTime * TimeInterval(index) / TimeInterval(sampleCount))
      peakMotion = zip(peakMotion, motion.magnitudes).map { max($0, $1) }
    }

    var factors: [CGFloat] = []
    for (component, jumpComponent) in jump.components.enumerated() {
      guard jumpComponent != 0 else {
        factors.append(0) // nothing to cancel for this component
        continue
      }
      let motionComponent = motionNow.components[component]
      guard motionComponent != 0, peakMotion[component] <= abs(motionComponent) * (1 + Constants.peakMotionTolerance) else {
        return nil
      }
      factors.append(jumpComponent / motionComponent)
    }
    return factors
  }

  /// Stacks one correction animation per timeline of the animations: a copy of an animation on that timeline whose
  /// offset is the timeline's offsets scaled by `factors`.
  ///
  /// Animations on one timeline deliver their offsets along the same curve at the same time, so they add up like one
  /// animation, and one copy corrects them all. The correction animations earlier retargets stacked are on their
  /// animations' timelines too, so they are folded into the new one and removed: a timeline carries one correction
  /// animation however many times its key path is retargeted.
  private func stackCorrectionAnimations(on animations: [InFlightAdditiveAnimation], scaledBy factors: [CGFloat], forKeyPath keyPath: String) {
    var animationsByTimeline: [[InFlightAdditiveAnimation]] = []
    var timelineIndices: [AnimationTimeline: Int] = [:]
    for additiveAnimation in animations {
      let timeline = AnimationTimeline(additiveAnimation.animation)
      if let index = timelineIndices[timeline] {
        animationsByTimeline[index].append(additiveAnimation)
      } else {
        timelineIndices[timeline] = animationsByTimeline.count
        animationsByTimeline.append([additiveAnimation])
      }
    }

    for sameTimelineAnimations in animationsByTimeline {
      let source = sameTimelineAnimations[0]
      var offset = sameTimelineAnimations.reduce(source.offset.zero) { $0 + $1.offset }.scaled(by: factors)
      for additiveAnimation in sameTimelineAnimations where additiveAnimation.animation.value(forKey: Constants.correctionTag) as? Bool == true {
        offset += additiveAnimation.offset
        removeAnimation(forKey: additiveAnimation.key)
      }

      // a copy of a basic animation is a basic animation, so the cast is forced
      let correctionAnimation = source.animation.copy() as! CABasicAnimation // swiftlint:disable:this force_cast
      correctionAnimation.fromValue = offset.value
      correctionAnimation.toValue = source.offset.zero.value
      correctionAnimation.delegate = nil // the copy must not report the animation's start and end a second time
      correctionAnimation.setValue(true, forKey: Constants.correctionTag)
      add(correctionAnimation, forKey: uniqueAnimationKey(key: keyPath))
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The key paths the render server clamps to [0, 1] after each animation, so additive animations of them don't
    /// compose on screen, see `animate(keyPath:to:timing:)`.
    static let clampedKeyPaths: Set<String> = ["opacity", "shadowOpacity"]

    /// The key-value coding key that marks a correction animation `retarget` stacked, so a later retarget can fold it.
    static let correctionTag = "ComposeUI.retargetCorrection"

    /// The rate the remaining motion is sampled at to check that it shrinks, twice the display rate to catch a fast spring's swings.
    static let motionSamplesPerSecond: TimeInterval = 120

    /// The most samples of the remaining motion, which bounds the work an absurd duration could ask for.
    static let maxMotionSamples = 2400

    /// The share the remaining motion may exceed its current magnitude by and still count as shrinking, which covers
    /// the rounding of the sample at `now` itself.
    static let peakMotionTolerance: CGFloat = 1e-6
  }
}

/// The timeline of an animation: when it runs, for how long, and along which curve.
///
/// Additive animations on one timeline deliver their offsets together, so they add up like one animation with the sum
/// of their offsets.
private struct AnimationTimeline: Hashable {

  private let beginTime: TimeInterval
  private let duration: TimeInterval
  private let speed: Float
  private let fillMode: CAMediaTimingFillMode

  private enum Curve: Hashable {
    case linear
    case timingFunction(controlPoints: [Float])
    case spring(mass: CGFloat, stiffness: CGFloat, damping: CGFloat, initialVelocity: CGFloat)
  }

  private let curve: Curve

  init(_ animation: CABasicAnimation) {
    beginTime = animation.beginTime
    duration = animation.duration
    speed = animation.speed
    fillMode = animation.fillMode
    if let spring = animation as? CASpringAnimation {
      curve = .spring(mass: spring.mass, stiffness: spring.stiffness, damping: spring.damping, initialVelocity: spring.initialVelocity)
    } else if let timingFunction = animation.timingFunction {
      var controlPoint1: [Float] = [0, 0]
      var controlPoint2: [Float] = [0, 0]
      timingFunction.getControlPoint(at: 1, values: &controlPoint1)
      timingFunction.getControlPoint(at: 2, values: &controlPoint2)
      curve = .timingFunction(controlPoints: controlPoint1 + controlPoint2)
    } else {
      curve = .linear
    }
  }
}

/// A value of a kind that animates additively, as its components: numbers, `CGSize` and `CGPoint`.
private struct AdditiveValue {

  private enum Kind {
    case number
    case size
    case point
  }

  private let kind: Kind

  /// The components: one for a number, width and height for a size, x and y for a point.
  let components: [CGFloat]

  /// Creates the value from a number, `CGSize` or `CGPoint`, as Core Animation boxes them.
  ///
  /// - Returns: `nil` for a value of another kind.
  init?(_ value: Any) {
    if let size = value as? CGSize {
      kind = .size
      components = [size.width, size.height]
    } else if let point = value as? CGPoint {
      kind = .point
      components = [point.x, point.y]
    } else if let number = value as? NSNumber {
      kind = .number
      components = [CGFloat(number.doubleValue)]
    } else {
      return nil
    }
  }

  private init(kind: Kind, components: [CGFloat]) {
    self.kind = kind
    self.components = components
  }

  /// The value as Core Animation boxes it.
  var value: Any {
    switch kind {
    case .number:
      return Double(components[0])
    case .size:
      return CGSize(width: components[0], height: components[1])
    case .point:
      return CGPoint(x: components[0], y: components[1])
    }
  }

  /// The zero of the value's kind.
  var zero: AdditiveValue {
    AdditiveValue(kind: kind, components: components.map { _ in 0 })
  }

  /// Whether every component is zero.
  var isZero: Bool {
    components.allSatisfy { $0 == 0 }
  }

  /// The components' magnitudes.
  var magnitudes: [CGFloat] {
    components.map(abs)
  }

  func isSameKind(as other: AdditiveValue) -> Bool {
    kind == other.kind
  }

  /// The value with every component multiplied by `factor`.
  func scaled(by factor: CGFloat) -> AdditiveValue {
    AdditiveValue(kind: kind, components: components.map { $0 * factor })
  }

  /// The value with each component multiplied by its factor.
  func scaled(by factors: [CGFloat]) -> AdditiveValue {
    AdditiveValue(kind: kind, components: zip(components, factors).map { $0 * $1 })
  }

  /// The component-wise sum of two values of the same kind.
  static func + (lhs: AdditiveValue, rhs: AdditiveValue) -> AdditiveValue {
    AdditiveValue(kind: lhs.kind, components: zip(lhs.components, rhs.components).map { $0 + $1 })
  }

  static func += (lhs: inout AdditiveValue, rhs: AdditiveValue) {
    lhs = lhs + rhs
  }

  /// The component-wise difference of two values of the same kind.
  static func - (lhs: AdditiveValue, rhs: AdditiveValue) -> AdditiveValue {
    AdditiveValue(kind: lhs.kind, components: zip(lhs.components, rhs.components).map { $0 - $1 })
  }
}
