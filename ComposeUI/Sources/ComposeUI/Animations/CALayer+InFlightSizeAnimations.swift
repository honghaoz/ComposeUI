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

    /// The layer's model size, which the animations add their values to.
    let modelSize: CGSize

    /// The time the longest animation has left, in seconds of the layer's time space.
    let remainingTime: TimeInterval

    /// The layer's current time.
    let now: TimeInterval

    /// The size the layer renders the given time from now.
    ///
    /// - Parameter time: The time from `now`, in seconds of the layer's time space.
    /// - Returns: The rendered size.
    func renderedSize(after time: TimeInterval) -> CGSize {
      var size = modelSize
      for sizeAnimation in animations {
        let animation = sizeAnimation.animation

        // an unset begin time resolves to the next commit, so the animation is evaluated from its start
        let started = animation.beginTime == 0 ? 0 : now - animation.beginTime

        let progress = CGFloat(animation.progress(forElapsedTime: (started + time) * TimeInterval(animation.speed)))
        size.width += sizeAnimation.from.width + (sizeAnimation.to.width - sizeAnimation.from.width) * progress
        size.height += sizeAnimation.from.height + (sizeAnimation.to.height - sizeAnimation.from.height) * progress
      }
      return size
    }

    /// The sizes the layer renders over the remaining time.
    func sampledSizes() -> [CGSize] {
      let sampledDuration = min(Constants.maxSampledDuration, remainingTime)
      let sampleCount = max(2, Int((sampledDuration * Constants.samplesPerSecond).rounded(.up)) + 1)
      return (0 ..< sampleCount).map { index in
        renderedSize(after: remainingTime * TimeInterval(index) / TimeInterval(sampleCount - 1))
      }
    }

    private enum Constants {

      /// The sampling rate of a value following the animating size.
      static let samplesPerSecond: TimeInterval = 60

      /// The most motion sampled at the sampling rate. A longer animation gets this much motion's worth of samples.
      ///
      /// For example, a 10s animation with 60 samples per second would get 600 samples. An animation longer than 10s
      /// would get fewer than 60 samples per second. This is to prevent an absurd duration from building millions of samples.
      static let maxSampledDuration: TimeInterval = 10
    }
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

      // a move without a resize leaves a size animation with no delta, and an ended animation has nothing to follow
      guard from != to, let animationRemainingTime = basicAnimation.remainingTime(at: now) else {
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

    return InFlightSizeAnimations(animations: animations, modelSize: bounds.size, remainingTime: remainingTime, now: now)
  }

  /// Animates a key path so it follows the layer's animating size, and sets its model value.
  ///
  /// A value derived from the size can't be animated additively like the size, so it is given as the values at the
  /// animations' sampled sizes, which become a keyframe animation that lands with the size, replacing the key path's
  /// in-flight animation.
  ///
  /// - Parameters:
  ///   - animations: The layer's in-flight size animations, see `inFlightSizeAnimations()`.
  ///   - keyPath: The key path to animate.
  ///   - modelValue: The model value to set, the value at the model size.
  ///   - values: The values at `animations.sampledSizes()`, one per size and in the same order.
  func animateFollowingSize(_ animations: InFlightSizeAnimations, keyPath: String, to modelValue: Any, values: [Any]) {
    guard values.count >= 2 else {
      ComposeUI.assertFailure("expected a value per sampled size, got \(values.count)")
      setKeyPathValue(keyPath, modelValue)
      return
    }

    let animation = CAKeyframeAnimation(keyPath: keyPath)
    animation.values = values
    animation.keyTimes = (0 ..< values.count).map {
      NSNumber(value: TimeInterval($0) / TimeInterval(values.count - 1))
    }
    animation.calculationMode = .linear
    animation.duration = animations.remainingTime
    animation.fillMode = .both

    // a paused size animation never lands, so the follower is kept after its duration, holding its last path until the
    // next update replaces it, instead of running out and exposing the model path under a frozen size
    if animations.animations.contains(where: { $0.animation.speed == 0 }) {
      animation.isRemovedOnCompletion = false
    }

    // the samples are measured from the layer's current time, so a running size animation needs the animation to begin
    // there too, or it lags the size by the time until the commit. when every size animation was added in this
    // transaction, they all begin at the next commit and so does the animation
    if animations.animations.contains(where: { $0.animation.beginTime != 0 }) {
      animation.beginTime = animations.now
    }
    add(animation, forKey: keyPath)

    setKeyPathValue(keyPath, modelValue)
  }
}
