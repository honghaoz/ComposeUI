//
//  AdditiveRetarget.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/22/26.
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
import simd

/// The additive branch of `CALayer.retarget(keyPath:to:)`: a key path whose in-flight animations are all additive.
///
/// The animations are offsets that land on the model value on their own, so they keep running. The jump the model
/// change would show is cancelled by a correction animation stacked on each of them: a copy of the animation with its
/// offset scaled, so the corrections add up to the jump now and fade exactly as the animations deliver the motion they
/// have left. The shown value glides to the new value along the animations' own curves.
struct AdditiveRetarget {

  /// An in-flight additive animation: a basic animation from an offset to zero.
  struct Animation {

    /// The animation's key on the layer.
    let key: String

    let animation: CABasicAnimation

    /// The offset the animation starts from, its `fromValue`, which shrinks to zero as it ends.
    let offset: AdditiveValue
  }

  /// An in-flight animation with the corrections earlier retargets stacked on it. The corrections are copies of the
  /// animation, so the group moves as one animation with the sum of the offsets.
  struct Group {

    let source: Animation

    let corrections: [Animation]

    /// The offsets of the source and its corrections, added up.
    let offset: AdditiveValue
  }

  /// The in-flight animations, grouped with their corrections.
  let groups: [Group]

  /// The jump the model change would show, the old value minus the new one.
  let jump: AdditiveValue

  /// The layer's current time.
  let now: TimeInterval

  /// Creates the retarget, or `nil` when the key path can't be retargeted additively: the render server clamps it after
  /// each animation, the values aren't numbers, sizes or points of one kind, or an animation isn't additive or isn't a
  /// basic animation from an offset to zero.
  init?(keyPath: String, animations: [InFlightAnimation], from oldValue: Any, to newValue: Any, at now: TimeInterval) {
    guard !Constants.clampedKeyPaths.contains(keyPath),
          let oldValue = AdditiveValue(oldValue),
          let newValue = AdditiveValue(newValue),
          oldValue.isSameKind(as: newValue)
    else {
      return nil
    }

    var additiveAnimations: [Animation] = []
    for inFlightAnimation in animations {
      guard let animation = inFlightAnimation.animation as? CABasicAnimation,
            animation.isAdditive,
            let offset = animation.additiveOffset(ofKind: oldValue, at: now)
      else {
        return nil
      }
      additiveAnimations.append(Animation(key: inFlightAnimation.key, animation: animation, offset: offset))
    }

    // a correction records the key of the animation it corrects. one whose animation is gone counts as an animation of
    // its own, and gets a correction itself
    let keys = Set(additiveAnimations.map(\.key))
    var correctionsBySource: [String: [Animation]] = [:]
    var sources: [Animation] = []
    for animation in additiveAnimations {
      if let source = animation.animation.value(forKey: Constants.correctionSourceKey) as? String, keys.contains(source) {
        correctionsBySource[source, default: []].append(animation)
      } else {
        sources.append(animation)
      }
    }
    groups = sources.map { source in
      let corrections = correctionsBySource[source.key] ?? []
      return Group(source: source, corrections: corrections, offset: corrections.reduce(source.offset) { $0 + $1.offset })
    }

    jump = oldValue - newValue
    self.now = now
  }

  /// The factors that scale the groups' remaining motion to the jump, per component.
  ///
  /// - Parameter remainingTime: The time the animations have left.
  /// - Returns: The factors, or `nil` when the motion can't be scaled: a component of the jump has no motion left, or
  ///   the motion grows again before it ends, which the scaling would amplify.
  func correctionFactors(over remainingTime: TimeInterval) -> SIMD2<Double>? {
    let motionNow = remainingMotion(at: now).components
    guard let peakMotion = peakRemainingMotion(over: remainingTime, from: motionNow) else {
      return nil
    }

    var factors = SIMD2<Double>.zero
    for component in jump.components.indices where jump.components[component] != 0 {
      let motionComponent = motionNow[component]
      guard motionComponent != 0, peakMotion[component] <= abs(motionComponent) * (1 + Constants.peakMotionTolerance) else {
        return nil
      }
      factors[component] = jump.components[component] / motionComponent
    }
    return factors
  }

  /// Stacks one correction animation on each group: a copy of its animation with the group's offset scaled by `factors`,
  /// folded with the group's earlier corrections, which are removed. So an animation carries one correction however
  /// many times its key path is retargeted.
  ///
  /// - Parameters:
  ///   - layer: The layer the animations run on.
  ///   - factors: The factors, see `correctionFactors(over:)`.
  ///   - keyPath: The retargeted key path, which the corrections are keyed by.
  func stackCorrectionAnimations(on layer: CALayer, scaledBy factors: SIMD2<Double>, forKeyPath keyPath: String) {
    for group in groups {
      // the new correction cancels the group's share of the jump and takes over what the earlier corrections cancelled
      var offset = group.offset.scaled(by: factors)
      for correction in group.corrections {
        offset += correction.offset
        layer.removeAnimation(forKey: correction.key)
      }

      // a copy of a basic animation is a basic animation, so the cast is forced
      let correctionAnimation = group.source.animation.copy() as! CABasicAnimation // swiftlint:disable:this force_cast
      correctionAnimation.fromValue = offset.value
      correctionAnimation.toValue = group.offset.zero.value
      correctionAnimation.delegate = nil // the copy must not report the animation's start and end a second time
      correctionAnimation.setValue(group.source.key, forKey: Constants.correctionSourceKey)
      layer.add(correctionAnimation, forKey: layer.uniqueAnimationKey(key: keyPath))
    }
  }

  /// The share of a group's offset it still has to deliver at a time, 1 before it begins and 0 once it has ended.
  private func remainingShare(of group: Group, at time: TimeInterval) -> Double {
    let animation = group.source.animation
    // an unset begin time resolves to the next commit, so the animation is taken to begin now
    let beginTime = animation.beginTime == 0 ? now : animation.beginTime
    return 1 - animation.progress(forElapsedTime: (time - beginTime) * TimeInterval(animation.speed))
  }

  /// The motion the groups have left at a time: what they still add to the model value.
  private func remainingMotion(at time: TimeInterval) -> AdditiveValue {
    groups.reduce(jump.zero) { $0 + $1.offset.scaled(by: SIMD2(repeating: remainingShare(of: $1, at: time))) }
  }

  /// The largest magnitude the remaining motion reaches before it ends, per component.
  ///
  /// - Returns: The magnitudes, or `nil` when the motion lasts longer than it can be sampled.
  private func peakRemainingMotion(over remainingTime: TimeInterval, from motionNow: SIMD2<Double>) -> SIMD2<Double>? {
    // a group on a curve that never overshoots shrinks all the way on its own, and so does a sum of such groups whose
    // offsets pull the same way. that is the common case, and nothing needs sampling. otherwise the motion is sampled
    // to its end: a spring swings back, and offsets pulling opposite ways can cancel out and grow again
    if groups.allSatisfy(\.source.animation.hasNoOvershoot), offsetsPullTheSameWay {
      return simd_abs(motionNow)
    }
    guard remainingTime <= Constants.maxSampledRemainingTime else {
      return nil
    }

    let sampleCount = max(2, Int((remainingTime * Constants.motionSamplesPerSecond).rounded(.up)))
    var peakMotion = simd_abs(motionNow)
    for index in 1 ... sampleCount {
      let time = now + remainingTime * TimeInterval(index) / TimeInterval(sampleCount)
      let motion = groups.reduce(SIMD2<Double>.zero) { $0 + $1.offset.components * remainingShare(of: $1, at: time) }
      peakMotion = pointwiseMax(peakMotion, simd_abs(motion))
    }
    return peakMotion
  }

  /// Whether, per component, the groups' non-zero offsets all have the same sign.
  private var offsetsPullTheSameWay: Bool {
    var signs = SIMD2<Double>.zero
    for group in groups {
      for component in group.offset.components.indices where group.offset.components[component] != 0 {
        let sign: Double = group.offset.components[component] > 0 ? 1 : -1
        if signs[component] == 0 {
          signs[component] = sign
        } else if signs[component] != sign {
          return false
        }
      }
    }
    return true
  }

  // MARK: - Constants

  private enum Constants {

    /// The key paths the render server clamps to [0, 1] after each animation, so additive animations of them don't
    /// compose on screen, see `animate(keyPath:to:timing:)`.
    static let clampedKeyPaths: Set<String> = ["opacity", "shadowOpacity"]

    /// The key-value coding key a correction animation records the key of the animation it corrects under.
    static let correctionSourceKey = "ComposeUI.retargetCorrectionSource"

    /// The rate the remaining motion is sampled at to check that it shrinks, twice the display rate to catch a fast spring's swings.
    static let motionSamplesPerSecond: TimeInterval = 120

    /// The longest remaining motion the check samples, 2400 samples at the rate. A longer motion isn't scaled.
    static let maxSampledRemainingTime: TimeInterval = 20

    /// The share the remaining motion may exceed its current magnitude by and still count as shrinking, which covers
    /// the rounding of the sample at `now` itself.
    static let peakMotionTolerance: CGFloat = 1e-6
  }
}

private extension CABasicAnimation {

  /// The offset the animation starts from, when it is a basic animation from an offset of `kind` to zero whose remaining
  /// motion can be computed, otherwise `nil`.
  ///
  /// The remaining motion is computed the way `progress(forElapsedTime:)` evaluates an animation, which doesn't cover
  /// repeats and time offsets. A scheduled animation is taken to hold its offset until it begins, which takes a
  /// backwards fill. An animation ending on a non-zero offset doesn't land on the model value.
  func additiveOffset(ofKind kind: AdditiveValue, at now: TimeInterval) -> AdditiveValue? {
    guard byValue == nil,
          repeatCount == 0,
          repeatDuration == 0,
          !autoreverses,
          timeOffset == 0,
          beginTime <= now || fillMode == .backwards || fillMode == .both,
          let offset = fromValue.flatMap({ AdditiveValue($0) }),
          offset.isSameKind(as: kind),
          let endOffset = toValue.flatMap({ AdditiveValue($0) }),
          endOffset.isSameKind(as: kind),
          endOffset.isZero
    else {
      return nil
    }
    return offset
  }

  /// Whether the animation's curve never overshoots, so its offset shrinks all the way: a linear curve, or a timing
  /// function whose control points stay within the unit square. A spring overshoots.
  var hasNoOvershoot: Bool {
    guard !(self is CASpringAnimation) else {
      return false
    }
    guard let timingFunction else {
      return true
    }
    var controlPoint1: [Float] = [0, 0]
    var controlPoint2: [Float] = [0, 0]
    timingFunction.getControlPoint(at: 1, values: &controlPoint1)
    timingFunction.getControlPoint(at: 2, values: &controlPoint2)
    return (0 ... 1).contains(controlPoint1[1]) && (0 ... 1).contains(controlPoint2[1])
  }
}

/// A value of a kind that animates additively, numbers, `CGSize` and `CGPoint`, as two components.
///
/// A number uses the first component and leaves the second at zero, so the component-wise math is the same for every
/// kind, and none of it allocates.
struct AdditiveValue {

  private enum Kind {
    case number
    case size
    case point
  }

  private let kind: Kind

  /// The components: the number and zero, width and height, or x and y.
  let components: SIMD2<Double>

  /// Creates the value from a number, `CGSize` or `CGPoint`, as Core Animation boxes them.
  ///
  /// - Returns: `nil` for a value of another kind.
  init?(_ value: Any) {
    if let size = value as? CGSize {
      kind = .size
      components = SIMD2(size.width, size.height)
    } else if let point = value as? CGPoint {
      kind = .point
      components = SIMD2(point.x, point.y)
    } else if let number = value as? NSNumber {
      kind = .number
      components = SIMD2(number.doubleValue, 0)
    } else {
      return nil
    }
  }

  private init(kind: Kind, components: SIMD2<Double>) {
    self.kind = kind
    self.components = components
  }

  /// The value as Core Animation boxes it.
  var value: Any {
    switch kind {
    case .number:
      return components.x
    case .size:
      return CGSize(width: components.x, height: components.y)
    case .point:
      return CGPoint(x: components.x, y: components.y)
    }
  }

  /// The zero of the value's kind.
  var zero: AdditiveValue {
    AdditiveValue(kind: kind, components: .zero)
  }

  /// Whether every component is zero.
  var isZero: Bool {
    components == .zero
  }

  func isSameKind(as other: AdditiveValue) -> Bool {
    kind == other.kind
  }

  /// The value with each component multiplied by its factor.
  func scaled(by factors: SIMD2<Double>) -> AdditiveValue {
    AdditiveValue(kind: kind, components: components * factors)
  }

  /// The component-wise sum of two values of the same kind.
  static func + (lhs: AdditiveValue, rhs: AdditiveValue) -> AdditiveValue {
    AdditiveValue(kind: lhs.kind, components: lhs.components + rhs.components)
  }

  static func += (lhs: inout AdditiveValue, rhs: AdditiveValue) {
    lhs = lhs + rhs
  }

  /// The component-wise difference of two values of the same kind.
  static func - (lhs: AdditiveValue, rhs: AdditiveValue) -> AdditiveValue {
    AdditiveValue(kind: lhs.kind, components: lhs.components - rhs.components)
  }
}
