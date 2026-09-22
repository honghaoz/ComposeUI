//
//  CALayer+UpdateShadow.swift
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

extension CALayer {

  /// Sets the shadow properties, animating the changes as the update asks.
  ///
  /// An animated update animates only the properties that changed, from the state the layer currently shows. A
  /// non-animated update continues the in-flight animations toward the new values, see `retarget(keyPath:to:)`.
  ///
  /// - Parameters:
  ///   - color: The shadow color.
  ///   - opacity: The shadow opacity.
  ///   - radius: The shadow radius.
  ///   - offset: The shadow offset.
  ///   - animationTiming: The update's animation timing, `nil` for a non-animated update.
  func updateShadow(color: CGColor, opacity: Float, radius: CGFloat, offset: CGSize, animationTiming: AnimationTiming?) {
    guard let animationTiming else {
      // no animation timing: continue the in-flight motion
      retarget(keyPath: "shadowColor", to: color)
      retarget(keyPath: "shadowOpacity", to: opacity)
      retarget(keyPath: "shadowRadius", to: radius)
      retarget(keyPath: "shadowOffset", to: offset)
      return
    }

    // only the properties whose model value differs from the target are animated:
    // - an unchanged additive one would add a zero-delta animation for no visual effect
    // - and an unchanged non-additive one would replace an in-flight animation to the same target and restart its easing.
    if shadowColor != color {
      animate(
        keyPath: "shadowColor",
        timing: animationTiming,
        from: { $0.presentation()?.shadowColor },
        to: { _ in color }
      )
    }

    if shadowOpacity != opacity {
      // the render server clamps the opacity for each animation, so additive animations wouldn't compose correctly,
      // so use non-additive animation instead
      animate(
        keyPath: "shadowOpacity",
        timing: animationTiming,
        from: { $0.presentation()?.shadowOpacity },
        to: { _ in opacity }
      )
    }

    if shadowRadius != radius {
      animate(keyPath: "shadowRadius", to: radius, timing: animationTiming)
    }

    if shadowOffset != offset {
      animate(keyPath: "shadowOffset", to: offset, timing: animationTiming)
    }
  }
}
