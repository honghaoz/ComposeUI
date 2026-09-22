//
//  CALayer+UpdatePath.swift
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

  /// Sets a path property, derived from the layer's size, animating the change as the update asks.
  ///
  /// While the size animates, the path follows it. Otherwise an animated update animates the path from the shown one
  /// and a non-animated one retargets it. An unchanged path is left alone.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of a `CGPath` property: `shadowPath`, or `path` on a `CAShapeLayer`.
  ///   - currentPath: The key path's current model value.
  ///   - lastSize: The size `currentPath` was made for, `nil` when unknown.
  ///   - newPath: The new path, the provider's path for the layer's model size.
  ///   - sizeAnimations: The in-flight size animations to follow, see `inFlightSizeAnimations()`.
  ///   - animationTiming: The update's animation timing, `nil` for a non-animated update.
  ///   - path: The provider, the path for a size of the layer.
  func updatePath(keyPath: String,
                  from currentPath: CGPath?,
                  madeFor lastSize: CGSize?,
                  to newPath: CGPath,
                  followingSizeAnimations sizeAnimations: InFlightSizeAnimations?,
                  animationTiming: AnimationTiming?,
                  path: (CGSize) -> CGPath)
  {
    guard keyPath == "shadowPath" || (keyPath == "path" && self is CAShapeLayer) else {
      ComposeUI.assertFailure("\"\(keyPath)\" isn't a path key path, expected \"shadowPath\" or a CAShapeLayer's \"path\"")
      return
    }

    guard currentPath != newPath else {
      // an in-flight animation of an unchanged path already lands on it
      return
    }

    // while the size animates, the path can follow it: the provider is called at the sizes the animation passes through
    // and the results become keyframes. the provider already makes the new shape, so if the shape changed too (say the
    // corner radius went from 8 to 20), the first keyframe already has it: the size glides, the shape jumps.
    // a non-animated update wants the new shape at once, so that is right for it. an animated update wants the shape
    // change to animate as well, so when the shape changed, the path is animated the ordinary way instead, from the
    // shown path to the new one: the shape morphs, but the path only stays close to the animating size, not exactly on it
    if let sizeAnimations, animationTiming == nil || !isShapeChanged(of: currentPath, madeFor: lastSize, path: path) {
      animateFollowingSize(sizeAnimations, keyPath: keyPath, to: newPath, value: { path($0) })
    } else if let animationTiming {
      animate(
        keyPath: keyPath,
        timing: animationTiming,
        from: { $0.presentation()?.value(forKeyPath: keyPath) },
        to: { _ -> Any? in newPath }
      )
    } else {
      retarget(keyPath: keyPath, to: newPath)
    }
  }

  /// Whether the provider changed the shape of `currentPath`, as opposed to only the size having changed.
  ///
  /// At the size `currentPath` was made for, the same shape gives the same path, so a different path there can only
  /// come from a changed shape.
  private func isShapeChanged(of currentPath: CGPath?, madeFor lastSize: CGSize?, path: (CGSize) -> CGPath) -> Bool {
    guard let currentPath, let lastSize else {
      return true // unknown, so a shape change can't be ruled out: the caller takes the branch that can't jump
    }
    return path(lastSize) != currentPath
  }
}
