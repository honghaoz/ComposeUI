//
//  CALayer+Animations.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
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

  /// Animate the layer's frame additively.
  ///
  /// - Parameters:
  ///   - to: The frame to animate to.
  ///   - timing: The animation timing.
  @_spi(Private)
  func animateFrame(to: CGRect, timing: AnimationTiming) {
    animate(
      keyPath: "position",
      timing: timing,
      from: { $0.position - $0.position(from: to) },
      to: { _ in .zero },
      model: { $0.position(from: to) },
      updateAnimation: { $0.isAdditive = true }
    )
    animate(
      keyPath: "bounds.size",
      timing: timing,
      from: { $0.bounds.size - to.size },
      to: { _ in .zero },
      model: { _ in to.size },
      updateAnimation: { $0.isAdditive = true }
    )
  }

  /// Animate the layer's value additively.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to animate.
  ///   - to: The value to animate to.
  ///   - timing: The animation timing.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate<T: FloatingPoint>(keyPath: String, to: T, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
    animate(
      keyPath: keyPath,
      timing: timing,
      from: { ($0.value(forKeyPath: keyPath) as! T) - to }, // swiftlint:disable:this force_cast
      to: { _ in 0 },
      model: { _ in to },
      updateAnimation: {
        $0.isAdditive = true
        updateAnimation?($0)
      }
    )
  }

  /// Animate the layer's value additively.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to animate.
  ///   - to: The value to animate to.
  ///   - timing: The animation timing.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate(keyPath: String, to: CGSize, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
    animate(
      keyPath: keyPath,
      timing: timing,
      from: { ($0.value(forKeyPath: keyPath) as! CGSize) - to }, // swiftlint:disable:this force_cast
      to: { _ in .zero },
      model: { _ in to },
      updateAnimation: {
        $0.isAdditive = true
        updateAnimation?($0)
      }
    )
  }

  /// Animate the layer's value additively.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to animate.
  ///   - to: The value to animate to.
  ///   - timing: The animation timing.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate(keyPath: String, to: CGPoint, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
    animate(
      keyPath: keyPath,
      timing: timing,
      from: { ($0.value(forKeyPath: keyPath) as! CGPoint) - to }, // swiftlint:disable:this force_cast
      to: { _ in .zero },
      model: { _ in to },
      updateAnimation: {
        $0.isAdditive = true
        updateAnimation?($0)
      }
    )
  }

  /// Add an animation to the layer.
  ///
  /// - Important: You must make sure the value type matches the key path type.
  ///
  /// - Parameters:
  ///   - key: The key to use for the animation. If `nil`, the key path will be used.
  ///   - keyPath: The key path to animate.
  ///   - timing: The animation timing.
  ///   - from: The value to animate from.
  ///   - to: The value to animate to.
  ///   - model: The model value to set. If `nil`, the `to` value will be used.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate<T>(key: String? = nil,
                  keyPath: String,
                  timing: AnimationTiming,
                  from: @escaping (CALayer) -> T,
                  to: @escaping (CALayer) -> T,
                  model: ((CALayer) -> T)? = nil,
                  updateAnimation: ((CABasicAnimation) -> Void)? = nil)
  {
    delay(timing.delay) { [weak self] in
      guard let self = self else {
        return
      }

      let model = model ?? to

      guard timing.timing.duration > 0 else {
        self.setKeyPathValue(keyPath, model(self))
        return
      }

      let animation = CABasicAnimation.makeAnimation(timing)
      animation.keyPath = keyPath
      animation.fromValue = from(self)
      animation.toValue = to(self)

      updateAnimation?(animation)

      let rawKey = key ?? keyPath
      let key: String
      if animation.isAdditive {
        key = self.uniqueAnimationKey(key: rawKey)
      } else {
        key = rawKey
      }
      self.add(animation, forKey: key)

      self.setKeyPathValue(keyPath, model(self))
    }
  }

  internal func setKeyPathValue(_ keyPath: String, _ value: Any) {
    #if os(macOS)
    if keyPath.hasPrefix("position"), let backedView {
      CATransaction.disableAnimations {
        /**
         For `NSView`, changing layer's frame related properties (aka `position`, `bounds.size`, `anchorPoint`) could
         make view's frame and layer's frame out of sync.

         For example:
         ```
         backedView.frame // (196.0, 315.0, 24.0, 28.0)
         layer.position // (196.0, 315.0)
         layer.position = CGPoint(200, 320)
         layer.position // (200.0, 320.0)
         layer.frame // (200.0, 320.0, 24.0, 28.0), which is correct
         backedView.frame // (196.0, 315.0, 24.0, 28.0), which is still the old frame, it's out of sync with the layer's frame
         ```

         For this case, we should correct the view's frame
         */

        position = value as! CGPoint // swiftlint:disable:this force_cast
        backedView.frame = frame
      }
      return
    }
    if keyPath.hasPrefix("bounds.size"), let backedView {
      CATransaction.disableAnimations {
        /**
         ```
         backedView.frame // (196.0, 315.0, 24.0, 28.0)
         layer.frame // (196.0, 315.0, 24.0, 28.0)

         layer.bounds.size = CGSize(50, 80)

         layer.frame // (196.0, 315.0, 50.0, 80.0), which is correct. Note that anchorPoint is (0, 0)
         backedView.frame // (196.0, 315.0, 24.0, 28.0) which is still the old frame, it's out of sync with the layer's frame

         on iOS, anchorPoint is (0.5, 0.5), changing the bounds.size will change the frame around the anchorPoint
         uiView.frame // (200.0, 150.0, 50.0, 50.0)
         uiView.layer.frame // (200.0, 150.0, 50.0, 50.0)

         uiView.layer.bounds.size = CGSize(80, 100)

         uiView.layer.frame // (185.0, 125.0, 80.0, 100.0)
         uiView.frame // (185.0, 125.0, 80.0, 100.0)
         ```
         */

        bounds.size = value as! CGSize // swiftlint:disable:this force_cast
        backedView.frame = frame
      }
      return
    }
    if keyPath.hasPrefix("anchorPoint"), let backedView {
      CATransaction.disableAnimations {
        /**
         ```
         // macOS behavior:
         layer.frame // (196.0, 315.0, 24.0, 28.0)
         backedView.frame // (196.0, 315.0, 24.0, 28.0)

         backingLayer.anchorPoint // (0.0, 0.0)
         backingLayer.anchorPoint = CGPoint(0.5, 0.5)

         backingLayer.frame // (184.0, 301.0, 24.0, 28.0)
         backedView.frame // (196.0, 315.0, 24.0, 28.0)

         // iOS behavior:
         uiView.frame // (200.0, 150.0, 50.0, 50.0)
         uiView.layer.frame // (200.0, 150.0, 50.0, 50.0)

         uiView.layer.anchorPoint = CGPoint(0, 0)

         uiView.layer.frame // (225.0, 175.0, 50.0, 50.0)
         uiView.frame // (225.0, 175.0, 50.0, 50.0)

         // summary: anchorPoint position in the parent view is the same, the view/layer's frame moves accordingly
         ```
         */
        anchorPoint = value as! CGPoint // swiftlint:disable:this force_cast
        backedView.frame = frame
      }
      return
    }
    #endif

    if keyPath == "opacity", let backedView {
      CATransaction.disableAnimations {
        let newValue = value as! Float // swiftlint:disable:this force_cast
        backedView.alpha = CGFloat(newValue)
        opacity = newValue
      }
      ComposeUI.assert(CGFloat(opacity) == backedView.alpha)
      return
    }

    CATransaction.disableAnimations {
      setValue(value, forKeyPath: keyPath)
    }
  }

  /// Get a unique animation key.
  ///
  /// This is useful when you want to add multiple animations, such as additive animations, with the same name to a layer.
  ///
  /// For example, if the animation for "position" already exists, the function will return "position-1".
  ///
  /// - Parameters:
  ///   - key: The desired animation key.
  /// - Returns: A unique animation key.
  @_spi(Private)
  func uniqueAnimationKey(key: String) -> String {
    var currentKey = key
    var counter = 1

    while animation(forKey: currentKey) != nil {
      currentKey = "\(key)-\(counter)"
      counter += 1
    }

    return currentKey
  }
}
