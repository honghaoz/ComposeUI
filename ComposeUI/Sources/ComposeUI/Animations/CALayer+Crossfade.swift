//
//  CALayer+Crossfade.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/20/26.
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

  /// Crossfades what the layer and its sublayers show, from what they showed at the last commit to what they show at the
  /// next one, for a change that can't be interpolated, such as a drawn text's color.
  ///
  /// The fade begins after the timing's delay, and the layer shows what it showed until then. A spring timing fades with
  /// an ease-out curve over the spring's duration, since a crossfade takes only a timing function. A crossfade replaces
  /// the one in flight, and starts from what the layer showed at the last commit instead of from the in-flight blend.
  ///
  /// - Parameter timing: The animation timing. A zero duration without a delay shows the change at once.
  func animateCrossfade(timing: AnimationTiming) {
    guard timing.timing.duration > 0 || timing.delay > 0 else {
      return
    }

    let transition = CATransition()
    transition.type = .fade

    // the transition takes the duration, speed and fill of an animation of the timing, such as a spring's duration and
    // the duration of a snap after a delay
    let animation = CABasicAnimation.makeAnimation(timing)
    transition.duration = animation.duration
    if animation.speed != 1 {
      transition.speed = animation.speed
    }
    transition.fillMode = animation.fillMode
    transition.applyPreferredFrameRateRange()

    switch timing.timing {
    case .spring:
      transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
    case .timingFunction(_, let timingFunction):
      transition.timingFunction = timingFunction
    }

    transition.beginTime = CAAnimation.addedBeginTime(at: currentTime, delay: timing.delay)

    // Core Animation keeps a transition under its own key, whatever the key it's added with
    add(transition, forKey: kCATransition)
    #if DEBUG
    WorkCounter.count(.animation)
    #endif
  }
}
