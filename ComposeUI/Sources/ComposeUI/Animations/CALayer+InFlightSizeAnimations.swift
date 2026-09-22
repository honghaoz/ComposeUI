//
//  CALayer+InFlightSizeAnimations.swift
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

extension CALayer {

  /// The layer's in-flight size animations: the additive `bounds.size` animations `animateFrame` adds.
  struct InFlightSizeAnimations {

    /// An in-flight size animation with its sizes.
    struct Animation {

      /// The animation.
      let animation: CABasicAnimation

      /// The animation's `fromValue`.
      let from: CGSize

      /// The animation's `toValue`.
      let to: CGSize
    }

    /// The in-flight animations.
    let animations: [Animation]

    /// The time the longest animation has left, in seconds of the layer's time space.
    let remainingTime: TimeInterval

    /// The layer's current time, which `remainingTime` and `renderedSize(after:with:)` are measured from.
    let now: TimeInterval
  }

  /// The layer's in-flight size animations.
  ///
  /// - Returns: The animations, or `nil` when the size isn't animating or is animated non-additively.
  func inFlightSizeAnimations() -> InFlightSizeAnimations? {
    let now = currentTime
    var animations: [InFlightSizeAnimations.Animation] = []
    var remainingTime: TimeInterval = 0
    for key in animationKeys() ?? [] {
      guard let animation = animation(forKey: key) as? CAPropertyAnimation, animation.keyPath == "bounds.size" else {
        continue
      }

      // a non-additive or keyframe size animation composes in a way the samples can't reproduce
      guard let basicAnimation = animation as? CABasicAnimation,
            basicAnimation.isAdditive,
            let from = basicAnimation.fromValue as? CGSize,
            let to = basicAnimation.toValue as? CGSize
      else {
        return nil
      }

      // a move without a resize leaves a size animation with no delta
      guard from != to else {
        continue
      }

      let scaledDuration = basicAnimation.speed > 0 ? basicAnimation.duration / TimeInterval(basicAnimation.speed) : basicAnimation.duration
      let animationRemainingTime = basicAnimation.beginTime == 0 ? scaledDuration : basicAnimation.beginTime + scaledDuration - now
      guard animationRemainingTime > 0 else {
        continue
      }

      animations.append(
        InFlightSizeAnimations.Animation(animation: basicAnimation, from: from, to: to)
      )
      remainingTime = max(remainingTime, animationRemainingTime)
    }

    guard !animations.isEmpty else {
      return nil
    }

    return InFlightSizeAnimations(animations: animations, remainingTime: remainingTime, now: now)
  }

  /// The size the layer renders the given time from now: the model size plus each in-flight animation's value.
  ///
  /// - Parameters:
  ///   - time: The time from `animations.now`, in seconds of the layer's time space.
  ///   - animations: The layer's in-flight size animations.
  /// - Returns: The rendered size.
  func renderedSize(after time: TimeInterval, with animations: InFlightSizeAnimations) -> CGSize {
    var size = bounds.size
    for sizeAnimation in animations.animations {
      let animation = sizeAnimation.animation
      // an unset begin time resolves to the next commit, so the animation is evaluated from its start
      let started = animation.beginTime == 0 ? 0 : animations.now - animation.beginTime
      let progress = CGFloat(animation.progress(forElapsedTime: (started + time) * TimeInterval(animation.speed)))
      size.width += sizeAnimation.from.width + (sizeAnimation.to.width - sizeAnimation.from.width) * progress
      size.height += sizeAnimation.from.height + (sizeAnimation.to.height - sizeAnimation.from.height) * progress
    }
    return size
  }

  /// Animates a key path so it follows the layer's animating size, and sets its model value.
  ///
  /// The size the layer renders is sampled over the animations' remaining time, the value is evaluated at each sample,
  /// and the samples become a keyframe animation that lands with the size, replacing the key path's in-flight animation.
  ///
  /// - Parameters:
  ///   - animations: The layer's in-flight size animations, see `inFlightSizeAnimations()`.
  ///   - keyPath: The key path to animate.
  ///   - modelValue: The model value to set, the value at the model size.
  ///   - value: The value at a rendered size.
  func animateFollowingSize(_ animations: InFlightSizeAnimations, keyPath: String, to modelValue: Any, value: (CGSize) -> Any) {
    // a value derived from the size can't be animated additively like the size, so it is sampled at the display rate
    // instead, capped since a long animation moves slowly enough for sparser samples to interpolate well
    let sampleCount = max(2, min(Constants.maxSampleCount, Int((animations.remainingTime * Constants.samplesPerSecond).rounded(.up)) + 1))

    var values: [Any] = []
    var keyTimes: [NSNumber] = []
    values.reserveCapacity(sampleCount)
    keyTimes.reserveCapacity(sampleCount)

    for index in 0 ..< sampleCount {
      let fraction = TimeInterval(index) / TimeInterval(sampleCount - 1)
      values.append(value(renderedSize(after: animations.remainingTime * fraction, with: animations)))
      keyTimes.append(NSNumber(value: fraction))
    }

    let animation = CAKeyframeAnimation(keyPath: keyPath)
    animation.values = values
    animation.keyTimes = keyTimes
    animation.calculationMode = .linear
    animation.duration = animations.remainingTime
    animation.fillMode = .both

    // the samples are measured from the layer's current time, so a running size animation needs the animation to begin
    // there too, or it lags the size by the time until the commit. when every size animation was added in this
    // transaction, they all begin at the next commit and so does the animation
    if animations.animations.contains(where: { $0.animation.beginTime != 0 }) {
      animation.beginTime = animations.now
    }
    add(animation, forKey: keyPath)

    setKeyPathValue(keyPath, modelValue)
  }

  // MARK: - Constants

  private enum Constants {

    /// The sampling rate of a value following the animating size.
    static let samplesPerSecond: TimeInterval = 60

    /// The most samples of a value following the animating size.
    static let maxSampleCount = 120
  }
}
