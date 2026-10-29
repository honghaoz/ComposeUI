//
//  AnimationInterpolation+Transform.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/28/26.
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

extension AnimationInterpolation {

  /// The transform a progress of the way from one transform to another, see `TransformInterpolator`.
  ///
  /// - Parameters:
  ///   - from: The from transform.
  ///   - to: The to transform.
  ///   - progress: The progress: 0 at the from transform, 1 at the to transform, and past them for a spring's overshoot.
  /// - Returns: The transform, or `nil` when the transforms don't interpolate, see `TransformInterpolator.init(from:to:)`.
  static func transform(from: CATransform3D, to: CATransform3D, progress: Double) -> CATransform3D? {
    TransformInterpolator(from: from, to: to)?.transform(atProgress: progress)
  }
}

/// Interpolates from one transform to another as Core Animation interpolates transforms, decomposing them once for any
/// number of progresses.
///
/// Two affine transforms interpolate by their translation, scale, rotation angle and the rest of their 2x2 matrix,
/// rotating the short way around. Other transforms interpolate by their perspective, translation, scale, skew and
/// rotation quaternion, rotating along the shorter arc.
struct TransformInterpolator {

  private enum Decompositions {
    case affine(from: AffineDecomposition, to: AffineDecomposition)
    case general(from: Decomposition, to: Decomposition)
  }

  private let from: CATransform3D
  private let to: CATransform3D
  private let decompositions: Decompositions

  /// Whether the transforms are affine and differ only in their scale and translation, so that the interpolation blends
  /// their matrices linearly.
  let isLinear: Bool

  /// Creates an interpolator from one transform to another.
  ///
  /// - Parameters:
  ///   - from: The from transform.
  ///   - to: The to transform.
  /// - Returns: `nil` when a transform that isn't affine doesn't decompose, as one that scales an axis to zero doesn't.
  init?(from: CATransform3D, to: CATransform3D) {
    self.from = from
    self.to = to
    if CATransform3DIsAffine(from), CATransform3DIsAffine(to) {
      let (fromDecomposition, toDecomposition) = AffineDecomposition.aligned(AffineDecomposition(from), AffineDecomposition(to))
      decompositions = .affine(from: fromDecomposition, to: toDecomposition)
      isLinear = fromDecomposition.hasSameRotationAndRest(as: toDecomposition)
    } else {
      guard let fromDecomposition = Decomposition(from), let toDecomposition = Decomposition(to) else {
        return nil
      }
      decompositions = .general(from: fromDecomposition, to: toDecomposition)
      isLinear = false
    }
  }

  /// The transform a progress of the way.
  ///
  /// - Parameter progress: The progress: 0 at the from transform, 1 at the to transform, and past them for a spring's
  ///   overshoot.
  /// - Returns: The transform, the from or to transform itself at a progress of 0 or 1.
  func transform(atProgress progress: Double) -> CATransform3D {
    switch progress {
    case 0:
      return from
    case 1:
      return to
    default:
      switch decompositions {
      case .affine(let from, let to):
        return AffineDecomposition.interpolated(from: from, to: to, progress: progress).transform
      case .general(let from, let to):
        return Decomposition.interpolated(from: from, to: to, progress: progress).transform
      }
    }
  }
}

/// An affine transform as its translation, scale, rotation angle and the rest of its 2x2 matrix, which interpolate
/// one by one.
///
/// The transform is the matrix, rotated by the angle, scaled by the scale, then translated.
private struct AffineDecomposition {

  var translationX: Double
  var translationY: Double
  var scaleX: Double
  var scaleY: Double
  var angle: Double
  var m11: Double
  var m12: Double
  var m21: Double
  var m22: Double

  init(_ transform: CATransform3D) {
    var row0x = Double(transform.m11)
    var row0y = Double(transform.m12)
    var row1x = Double(transform.m21)
    var row1y = Double(transform.m22)
    translationX = Double(transform.m41)
    translationY = Double(transform.m42)

    scaleX = (row0x * row0x + row0y * row0y).squareRoot()
    scaleY = (row1x * row1x + row1y * row1y).squareRoot()

    // a negative determinant flips an axis, which goes to the scale of the axis whose row is closer to its unit vector
    if row0x * row1y - row0y * row1x < 0 {
      if row0x < row1y {
        scaleX = -scaleX
      } else {
        scaleY = -scaleY
      }
    }

    if scaleX != 0 {
      row0x /= scaleX
      row0y /= scaleX
    }
    if scaleY != 0 {
      row1x /= scaleY
      row1y /= scaleY
    }

    angle = atan2(row0y, row0x)
    if angle != 0 {
      // the rows rotate by the negative angle, which leaves the rest of the matrix
      let sine = -row0y
      let cosine = row0x
      let (a, b, c, d) = (row0x, row0y, row1x, row1y)
      row0x = cosine * a + sine * c
      row0y = cosine * b + sine * d
      row1x = -sine * a + cosine * c
      row1y = -sine * b + cosine * d
    }

    m11 = row0x
    m12 = row0y
    m21 = row1x
    m22 = row1y
  }

  /// The transform the decomposition describes.
  var transform: CATransform3D {
    var matrix = CATransform3DIdentity
    matrix.m11 = CGFloat(m11)
    matrix.m12 = CGFloat(m12)
    matrix.m21 = CGFloat(m21)
    matrix.m22 = CGFloat(m22)
    matrix = CATransform3DConcat(CATransform3DMakeRotation(CGFloat(angle), 0, 0, 1), matrix)
    matrix = CATransform3DConcat(CATransform3DMakeScale(CGFloat(scaleX), CGFloat(scaleY), 1), matrix)
    matrix.m41 = CGFloat(translationX)
    matrix.m42 = CGFloat(translationY)
    return matrix
  }

  /// Whether the decomposition has the same angle and rest of the matrix as another, so that only the scale and the
  /// translation change between them, each linearly.
  ///
  /// - Parameter other: The other decomposition, aligned with this one, see `aligned(_:_:)`.
  /// - Returns: `true` if they have the same angle and rest of the matrix.
  func hasSameRotationAndRest(as other: AffineDecomposition) -> Bool {
    angle == other.angle && m11 == other.m11 && m12 == other.m12 && m21 == other.m21 && m22 == other.m22
  }

  /// The decompositions with their flips and angles made comparable, so that they interpolate without a flip and the
  /// rotation goes the short way around.
  static func aligned(_ from: AffineDecomposition, _ to: AffineDecomposition) -> (AffineDecomposition, AffineDecomposition) {
    var from = from
    var to = to

    // an x axis flipped on one side and a y axis on the other make a half turn
    if (from.scaleX < 0 && to.scaleY < 0) || (from.scaleY < 0 && to.scaleX < 0) {
      from.scaleX = -from.scaleX
      from.scaleY = -from.scaleY
      from.angle += from.angle < 0 ? .pi : -.pi
    }

    // a zero angle counts as a full turn
    if from.angle == 0 {
      from.angle = 2 * .pi
    }
    if to.angle == 0 {
      to.angle = 2 * .pi
    }
    if abs(from.angle - to.angle) > .pi {
      if from.angle > to.angle {
        from.angle -= 2 * .pi
      } else {
        to.angle -= 2 * .pi
      }
    }
    return (from, to)
  }

  /// The decomposition a progress of the way from one aligned decomposition to another, see `aligned(_:_:)`.
  static func interpolated(from: AffineDecomposition, to: AffineDecomposition, progress: Double) -> AffineDecomposition {
    func blend(_ from: Double, _ to: Double) -> Double {
      from + (to - from) * progress
    }

    var result = from
    result.translationX = blend(from.translationX, to.translationX)
    result.translationY = blend(from.translationY, to.translationY)
    result.scaleX = blend(from.scaleX, to.scaleX)
    result.scaleY = blend(from.scaleY, to.scaleY)
    result.angle = blend(from.angle, to.angle)
    result.m11 = blend(from.m11, to.m11)
    result.m12 = blend(from.m12, to.m12)
    result.m21 = blend(from.m21, to.m21)
    result.m22 = blend(from.m22, to.m22)
    return result
  }
}

/// A transform as its perspective, translation, scale, skew and rotation quaternion, which interpolate one by one.
///
/// The transform scales, skews, rotates, translates, then applies the perspective.
private struct Decomposition {

  var perspective: SIMD4<Double>
  var translation: SIMD3<Double>
  var scale: SIMD3<Double>

  /// The skew factors of x along y, x along z and y along z.
  var skew: SIMD3<Double>

  /// The rotation as a unit quaternion, (x, y, z, w).
  var quaternion: SIMD4<Double>

  init?(_ transform: CATransform3D) {
    let row0 = SIMD4(Double(transform.m11), Double(transform.m12), Double(transform.m13), Double(transform.m14))
    let row1 = SIMD4(Double(transform.m21), Double(transform.m22), Double(transform.m23), Double(transform.m24))
    let row2 = SIMD4(Double(transform.m31), Double(transform.m32), Double(transform.m33), Double(transform.m34))
    let row3 = SIMD4(Double(transform.m41), Double(transform.m42), Double(transform.m43), Double(transform.m44))

    // the matrix without its perspective column solves the perspective, and has to be invertible for the rest to
    // decompose
    let perspectiveMatrix = simd_double4x4(columns: (
      SIMD4(row0.x, row1.x, row2.x, row3.x),
      SIMD4(row0.y, row1.y, row2.y, row3.y),
      SIMD4(row0.z, row1.z, row2.z, row3.z),
      SIMD4(0, 0, 0, 1)
    ))
    guard perspectiveMatrix.determinant != 0 else {
      return nil
    }

    if row0.w != 0 || row1.w != 0 || row2.w != 0 {
      perspective = perspectiveMatrix.inverse * SIMD4(row0.w, row1.w, row2.w, row3.w)
    } else {
      perspective = SIMD4(0, 0, 0, 1)
    }

    translation = SIMD3(row3.x, row3.y, row3.z)

    var axisX = SIMD3(row0.x, row0.y, row0.z)
    var axisY = SIMD3(row1.x, row1.y, row1.z)
    var axisZ = SIMD3(row2.x, row2.y, row2.z)
    var scale = SIMD3<Double>(repeating: 0)
    var skew = SIMD3<Double>(repeating: 0)

    scale.x = length(axisX)
    axisX /= scale.x

    skew.x = dot(axisX, axisY)
    axisY -= skew.x * axisX
    scale.y = length(axisY)
    axisY /= scale.y
    skew.x /= scale.y

    skew.y = dot(axisX, axisZ)
    axisZ -= skew.y * axisX
    skew.z = dot(axisY, axisZ)
    axisZ -= skew.z * axisY
    scale.z = length(axisZ)
    axisZ /= scale.z
    skew.y /= scale.z
    skew.z /= scale.z

    // the axes are orthonormal now, and a negative determinant flips the coordinate system, which goes to the scale
    if dot(axisX, cross(axisY, axisZ)) < 0 {
      scale = -scale
      axisX = -axisX
      axisY = -axisY
      axisZ = -axisZ
    }

    self.scale = scale
    self.skew = skew
    quaternion = Decomposition.quaternion(axisX, axisY, axisZ)
  }

  /// The unit quaternion of a rotation matrix's rows.
  private static func quaternion(_ row0: SIMD3<Double>, _ row1: SIMD3<Double>, _ row2: SIMD3<Double>) -> SIMD4<Double> {
    // the largest of the four components divides the others, which keeps the division away from zero
    let trace = row0.x + row1.y + row2.z + 1
    if trace > 1e-4 {
      let s = 0.5 / trace.squareRoot()
      return SIMD4((row2.y - row1.z) * s, (row0.z - row2.x) * s, (row1.x - row0.y) * s, 0.25 / s)
    } else if row0.x > row1.y, row0.x > row2.z {
      let s = (1 + row0.x - row1.y - row2.z).squareRoot() * 2
      return SIMD4(0.25 * s, (row0.y + row1.x) / s, (row0.z + row2.x) / s, (row2.y - row1.z) / s)
    } else if row1.y > row2.z {
      let s = (1 + row1.y - row0.x - row2.z).squareRoot() * 2
      return SIMD4((row0.y + row1.x) / s, 0.25 * s, (row1.z + row2.y) / s, (row0.z - row2.x) / s)
    } else {
      let s = (1 + row2.z - row0.x - row1.y).squareRoot() * 2
      return SIMD4((row0.z + row2.x) / s, (row1.z + row2.y) / s, 0.25 * s, (row1.x - row0.y) / s)
    }
  }

  /// The transform the decomposition describes.
  var transform: CATransform3D {
    var matrix = CATransform3DIdentity
    matrix.m14 = CGFloat(perspective.x)
    matrix.m24 = CGFloat(perspective.y)
    matrix.m34 = CGFloat(perspective.z)
    matrix.m44 = CGFloat(perspective.w)

    matrix = CATransform3DConcat(
      CATransform3DMakeTranslation(CGFloat(translation.x), CGFloat(translation.y), CGFloat(translation.z)),
      matrix
    )

    let (x, y, z, w) = (quaternion.x, quaternion.y, quaternion.z, quaternion.w)
    var rotation = CATransform3DIdentity
    rotation.m11 = CGFloat(1 - 2 * (y * y + z * z))
    rotation.m12 = CGFloat(2 * (x * y - z * w))
    rotation.m13 = CGFloat(2 * (x * z + y * w))
    rotation.m21 = CGFloat(2 * (x * y + z * w))
    rotation.m22 = CGFloat(1 - 2 * (x * x + z * z))
    rotation.m23 = CGFloat(2 * (y * z - x * w))
    rotation.m31 = CGFloat(2 * (x * z - y * w))
    rotation.m32 = CGFloat(2 * (y * z + x * w))
    rotation.m33 = CGFloat(1 - 2 * (x * x + y * y))
    matrix = CATransform3DConcat(rotation, matrix)

    if skew.z != 0 {
      var skewYZ = CATransform3DIdentity
      skewYZ.m32 = CGFloat(skew.z)
      matrix = CATransform3DConcat(skewYZ, matrix)
    }
    if skew.y != 0 {
      var skewXZ = CATransform3DIdentity
      skewXZ.m31 = CGFloat(skew.y)
      matrix = CATransform3DConcat(skewXZ, matrix)
    }
    if skew.x != 0 {
      var skewXY = CATransform3DIdentity
      skewXY.m21 = CGFloat(skew.x)
      matrix = CATransform3DConcat(skewXY, matrix)
    }

    return CATransform3DConcat(CATransform3DMakeScale(CGFloat(scale.x), CGFloat(scale.y), CGFloat(scale.z)), matrix)
  }

  /// The decomposition a progress of the way from one decomposition to another, with the rotation along the shorter arc.
  static func interpolated(from: Decomposition, to: Decomposition, progress: Double) -> Decomposition {
    var result = from
    result.perspective = from.perspective + (to.perspective - from.perspective) * progress
    result.translation = from.translation + (to.translation - from.translation) * progress
    result.scale = from.scale + (to.scale - from.scale) * progress
    result.skew = from.skew + (to.skew - from.skew) * progress
    result.quaternion = slerp(from: from.quaternion, to: to.quaternion, progress: progress)
    return result
  }

  /// The quaternion a progress of the way from one unit quaternion to another along the shorter arc.
  private static func slerp(from: SIMD4<Double>, to: SIMD4<Double>, progress: Double) -> SIMD4<Double> {
    var from = from
    var cosine = dot(from, to)

    // a quaternion and its negation are the same rotation, and the one closer to the other quaternion is on the shorter arc
    if cosine < 0 {
      from = -from
      cosine = -cosine
    }

    if 1 - cosine >= 1e-4 {
      let angle = acos(cosine)
      let inverseSine = 1 / sin(angle)
      return from * (sin(angle * (1 - progress)) * inverseSine) + to * (sin(angle * progress) * inverseSine)
    } else {
      // Core Animation blends rotations less than about 1.6° apart linearly, normalized to stay a rotation, instead of
      // dividing by the sine of a tiny angle
      return simd_normalize(from * (1 - progress) + to * progress)
    }
  }
}
