//
//  TransformChanges.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/29/26.
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

/// The changes of a transform in flight, each from the transform that the change before it ends at to its own.
///
/// A change made during another one stacks on it, as frame changes and an additive path's changes do, see `PathChanges`,
/// instead of starting over from the transform shown. Each change goes on along its own timing, and the transform shown
/// is the first change's transform so far, followed by each later change's way so far from where it starts. A change
/// that starts at rest adds no speed at first, so the motion of the changes in flight carries on.
struct TransformChanges {

  /// A change, with what it takes to follow the changes before it.
  private struct Change {

    /// The change's motion, from the transform that the change before it ends at to the change's own.
    let motion: TransformMotion

    /// The inverse of the transform that the change starts from, which takes that transform off the transforms of the
    /// changes before it, so that only the change's way from it follows them.
    let inverseStart: CATransform3D
  }

  /// The first change, which starts from the transform that the layer showed, and isn't in an array, so that changes
  /// of one change don't allocate.
  private let first: Change

  /// The changes after the first, in the order they were made.
  private let rest: [Change]

  /// Creates the changes of one change.
  ///
  /// - Parameter motion: The change's motion.
  init(_ motion: TransformMotion) {
    first = Change(motion: motion, inverseStart: CATransform3DIdentity)
    rest = []
  }

  private init(first: Change, rest: [Change]) {
    self.first = first
    self.rest = rest
  }

  /// The time the first change begins, in the layer's time space.
  var beginTime: TimeInterval {
    rest.reduce(first.motion.beginTime) { min($0, $1.motion.beginTime) }
  }

  /// The time the last change ends, in the layer's time space.
  var endTime: TimeInterval {
    rest.reduce(first.motion.endTime) { max($0, $1.motion.endTime) }
  }

  /// Whether a change never ends, as a spring without damping doesn't.
  var neverFinishes: Bool {
    first.motion.neverFinishes || rest.contains { $0.motion.neverFinishes }
  }

  /// The transform at a time: the first change's transform so far, followed by each later change's way so far from
  /// where it starts.
  ///
  /// It's always inlined, since the changes are too big for registers, so a call would copy them to pass them, for each
  /// keyframe that follows them.
  ///
  /// - Parameter time: The time, in the layer's time space.
  /// - Returns: The transform.
  @inline(__always)
  func transform(at time: TimeInterval) -> CATransform3D {
    var transform = first.motion.transform(at: time)
    var index = 0
    while index < rest.count {
      transform = CATransform3DConcat(CATransform3DConcat(transform, rest[index].inverseStart), rest[index].motion.transform(at: time))
      index += 1
    }
    return transform
  }

  /// The changes with a change stacked on them, from the transform that the last of them ends at.
  ///
  /// The changes that have landed, other than the last, whose transform the new change starts from, are left out.
  ///
  /// - Parameters:
  ///   - motion: The change's motion, from the transform that the last change ends at.
  ///   - time: The time the change is made at, in the layer's time space.
  /// - Returns: The changes, or `nil` when the transform that the last change ends at has no inverse.
  func stacking(_ motion: TransformMotion, at time: TimeInterval) -> TransformChanges? {
    guard let inverseStart = Self.inverse(of: (rest.last ?? first).motion.target) else {
      return nil
    }

    // a landed change ends at its target, which the next change takes off again, so the next change can take off the
    // landed change's start instead, and leave the landed change out
    var keptChanges: [Change] = []
    keptChanges.reserveCapacity(rest.count + 2)
    var landedStart: CATransform3D?
    var index = 0
    while index <= rest.count {
      let change = index == 0 ? first : rest[index - 1]
      if index < rest.count, time >= change.motion.endTime {
        landedStart = landedStart ?? change.inverseStart
      } else {
        keptChanges.append(Change(motion: change.motion, inverseStart: landedStart ?? change.inverseStart))
        landedStart = nil
      }
      index += 1
    }
    keptChanges.append(Change(motion: motion, inverseStart: inverseStart))

    // removing the first change kept leaves the rest in the array's storage, instead of copying them into a new one
    let firstKept = keptChanges.removeFirst()
    return TransformChanges(first: firstKept, rest: keptChanges)
  }

  /// The inverse of a transform.
  ///
  /// - Parameter transform: The transform.
  /// - Returns: The inverse, or `nil` when the transform has none, as one that scales an axis to zero doesn't.
  private static func inverse(of transform: CATransform3D) -> CATransform3D? {
    // the matrix takes the transform's rows as its columns, since an array of rows would allocate, so it and its inverse
    // are the transposes of the transform and the transform's inverse
    let matrix = simd_double4x4(
      SIMD4(Double(transform.m11), Double(transform.m12), Double(transform.m13), Double(transform.m14)),
      SIMD4(Double(transform.m21), Double(transform.m22), Double(transform.m23), Double(transform.m24)),
      SIMD4(Double(transform.m31), Double(transform.m32), Double(transform.m33), Double(transform.m34)),
      SIMD4(Double(transform.m41), Double(transform.m42), Double(transform.m43), Double(transform.m44))
    )
    guard matrix.determinant != 0 else {
      return nil
    }
    let inverse = matrix.inverse
    return CATransform3D(
      m11: CGFloat(inverse[0][0]), m12: CGFloat(inverse[0][1]), m13: CGFloat(inverse[0][2]), m14: CGFloat(inverse[0][3]),
      m21: CGFloat(inverse[1][0]), m22: CGFloat(inverse[1][1]), m23: CGFloat(inverse[1][2]), m24: CGFloat(inverse[1][3]),
      m31: CGFloat(inverse[2][0]), m32: CGFloat(inverse[2][1]), m33: CGFloat(inverse[2][2]), m34: CGFloat(inverse[2][3]),
      m41: CGFloat(inverse[3][0]), m42: CGFloat(inverse[3][1]), m43: CGFloat(inverse[3][2]), m44: CGFloat(inverse[3][3])
    )
  }
}
