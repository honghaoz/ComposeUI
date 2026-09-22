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

  /// Sets the shadow path following the in-flight size animations if any.
  ///
  /// - Parameters:
  ///   - newPath: The new path, for the layer's model size.
  ///   - sizeAnimations: The in-flight size animations to follow, see `inFlightSizeAnimations()`.
  ///   - isShapeChanged: Whether the path's shape changed, see `isShapeChanged(current:previous:)`.
  ///   - sampledPaths: The paths for `sizeAnimations.sampledSizes()`, called only to follow the size.
  ///   - animationTiming: The update's animation timing, `nil` for a non-animated update.
  func updateShadowPath(to newPath: CGPath,
                        followingSizeAnimations sizeAnimations: InFlightSizeAnimations?,
                        isShapeChanged: Bool,
                        sampledPaths: () -> [CGPath],
                        animationTiming: AnimationTiming?)
  {
    updatePath(
      keyPath: "shadowPath",
      from: shadowPath,
      to: newPath,
      followingSizeAnimations: sizeAnimations,
      isShapeChanged: isShapeChanged,
      sampledPaths: sampledPaths,
      animationTiming: animationTiming
    )
  }

  /// Whether the path's shape changed.
  ///
  /// - Parameters:
  ///   - currentPath: The current model path, `nil` when there is none yet.
  ///   - previousPath: The path the provider gives now for the size `currentPath` was made for, `nil` when that size is unknown.
  static func isShapeChanged(current currentPath: CGPath?, previous previousPath: CGPath?) -> Bool {
    guard let currentPath else {
      return false // no path yet, so there is no shape to morph from, and following the size shows the new one at once
    }
    guard let previousPath else {
      return true // unknown, so a shape change can't be ruled out: the caller takes the branch that can't jump
    }
    return previousPath != currentPath
  }

  fileprivate func updatePath(keyPath: String,
                              from currentPath: CGPath?,
                              to newPath: CGPath,
                              followingSizeAnimations sizeAnimations: InFlightSizeAnimations?,
                              isShapeChanged: Bool,
                              sampledPaths: () -> [CGPath],
                              animationTiming: AnimationTiming?)
  {
    guard currentPath != newPath else {
      // the path didn't change, so there is nothing to do.
      // example: a refresh changed only the shadow color while the size animates. the path animation from the earlier
      // update keeps following the size and lands on this path.
      return
    }

    // while the size animates, the path can follow it: the paths at the sizes the animation passes through become
    // keyframes. those paths already have the new shape, so if the shape changed too (say the corner radius went from
    // 8 to 20), the first keyframe already has it: the size glides, the shape jumps.
    // a non-animated update wants the new shape at once, so that is right for it. an animated update wants the shape
    // change to animate as well, so when the shape changed, the path is animated the ordinary way instead, from the
    // shown path to the new one: the shape morphs, but the path only stays close to the animating size, not exactly on it
    if let sizeAnimations, animationTiming == nil || !isShapeChanged {
      animateFollowingSize(sizeAnimations, keyPath: keyPath, to: newPath, values: sampledPaths())
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
}

extension CAShapeLayer {

  /// Sets the path following the in-flight size animations if any.
  func updatePath(to newPath: CGPath,
                  followingSizeAnimations sizeAnimations: InFlightSizeAnimations?,
                  isShapeChanged: Bool,
                  sampledPaths: () -> [CGPath],
                  animationTiming: AnimationTiming?)
  {
    updatePath(
      keyPath: "path",
      from: path,
      to: newPath,
      followingSizeAnimations: sizeAnimations,
      isShapeChanged: isShapeChanged,
      sampledPaths: sampledPaths,
      animationTiming: animationTiming
    )
  }
}
