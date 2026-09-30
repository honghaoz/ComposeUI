//
//  AnimationInterpolation.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/26.
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

/// Interpolates animation values the way Core Animation does: numbers, sizes and points component by component,
/// colors component by component in extended sRGB with straight alpha, see `ExtendedSRGB`, and paths with the same
/// segments point by point, see `PathPoints`.
///
/// It gives the value for a progress, which `AnimationCurve` gives for a time.
enum AnimationInterpolation {

  /// The value a progress of the way from one animation value to another.
  ///
  /// - Parameters:
  ///   - from: The from value, as Core Animation keeps it: an `NSNumber`, an `NSValue` of a size or a point, a color or
  ///     a path.
  ///   - to: The to value.
  ///   - progress: The progress: 0 at the from value, 1 at the to value, and past them for a spring's overshoot.
  /// - Returns: The value, the from or to value itself at a progress of 0 or 1. `nil` for values that aren't numbers,
  ///   sizes, points, colors or paths of the same kind, paths with other segments, or colors that don't convert to
  ///   extended sRGB.
  static func value(from: AnyObject, to: AnyObject, progress: Double) -> Any? {
    switch progress {
    case 0:
      return from
    case 1:
      return to
    default:
      break
    }

    switch (CFGetTypeID(from), CFGetTypeID(to)) {
    case (CGColor.typeID, CGColor.typeID):
      return color(from: unsafeDowncast(from, to: CGColor.self), to: unsafeDowncast(to, to: CGColor.self), progress: progress)
    case (CGPath.typeID, CGPath.typeID):
      return path(from: unsafeDowncast(from, to: CGPath.self), to: unsafeDowncast(to, to: CGPath.self), progress: progress)
    default:
      guard let from = AdditiveValue(from), let to = AdditiveValue(to), from.isSameKind(as: to) else {
        return nil
      }
      return (from + (to - from).scaled(by: progress)).value
    }
  }

  /// The color a progress of the way from one color to another, interpolated component by component in extended sRGB,
  /// with straight alpha, as Core Animation interpolates colors of any color space.
  ///
  /// - Parameters:
  ///   - from: The from color.
  ///   - to: The to color.
  ///   - progress: The progress.
  /// - Returns: The color, in extended sRGB, or `nil` when a color doesn't convert to extended sRGB, such as a pattern.
  static func color(from: CGColor, to: CGColor, progress: Double) -> CGColor? {
    guard let from = ExtendedSRGB.components(of: from), let to = ExtendedSRGB.components(of: to) else {
      return nil
    }
    return ExtendedSRGB.color(components: from + (to - from) * progress)
  }

  /// The path a progress of the way from one path to another, interpolated point by point.
  ///
  /// - Parameters:
  ///   - from: The from path.
  ///   - to: The to path.
  ///   - progress: The progress.
  /// - Returns: The path, or `nil` when the paths have other segments or points that aren't finite.
  static func path(from: CGPath, to: CGPath, progress: Double) -> CGPath? {
    let from = PathPoints(from)
    let to = PathPoints(to)
    guard from.hasSameSegments(as: to), from.isFinite, to.isFinite else {
      return nil
    }
    return from.adding(to.subtracting(from), multipliedBy: CGFloat(progress)).path
  }
}
