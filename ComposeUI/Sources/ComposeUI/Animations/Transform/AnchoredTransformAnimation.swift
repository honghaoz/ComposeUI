//
//  AnchoredTransformAnimation.swift
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

// MARK: - AnchoredTransformAnimation

/// An animation of a layer's transform about a point of the layer, see `CALayer.updateTransform(_:anchor:oldSize:animationTiming:)`.
///
/// It keeps the transform and its changes, so that a later update computes the transform that it shows instead of
/// reading it back. They're stored properties of the animation's class, as a key-value mark on an animation costs about
/// as much as making the animation, see `FrameAnimation`.
protocol AnchoredTransformAnimation: CAPropertyAnimation {

  /// The transform that the animation ends at, before it applies about the point.
  var transform: CATransform3D { get set }

  /// The point's offset from the layer's anchor point, in the unit space of the layer's bounds.
  var pivotOffset: SIMD2<Double> { get set }

  /// The transform's changes, or `nil` when the transform stays while the layer's size animates.
  var changes: TransformChanges? { get }
}

/// An anchored transform animation of keyframes, at the size that the layer shows at each keyframe.
final class AnchoredTransformKeyframeAnimation: CAKeyframeAnimation, AnchoredTransformAnimation {

  var transform = CATransform3DIdentity
  var pivotOffset = SIMD2<Double>.zero
  var changes: TransformChanges?

  override func copy(with zone: NSZone? = nil) -> Any {
    // Core Animation copies an animation when it's added, without the Swift properties, so the copy takes them here
    let copy = super.copy(with: zone) as! AnchoredTransformKeyframeAnimation // swiftlint:disable:this force_cast
    copy.transform = transform
    copy.pivotOffset = pivotOffset
    copy.changes = changes
    return copy
  }
}

// MARK: - AnchoredTransformMotionAnimation

/// An anchored transform animation of one change, from one transform about the point to another, which Core Animation
/// interpolates.
///
/// It keeps its change as a motion rather than changes, which hold an array, so that copying and freeing the animation
/// retain and release nothing.
protocol AnchoredTransformMotionAnimation: AnchoredTransformAnimation {

  /// The transform's change.
  var motion: TransformMotion? { get set }
}

extension AnchoredTransformMotionAnimation {

  var changes: TransformChanges? {
    motion.map { TransformChanges($0) }
  }
}

/// An anchored transform animation of a timing function, from one transform about the point to another.
final class AnchoredTransformBasicAnimation: CABasicAnimation, AnchoredTransformMotionAnimation {

  var transform = CATransform3DIdentity
  var pivotOffset = SIMD2<Double>.zero
  var motion: TransformMotion?

  override func copy(with zone: NSZone? = nil) -> Any {
    // Core Animation copies an animation when it's added, without the Swift properties, so the copy takes them here
    let copy = super.copy(with: zone) as! AnchoredTransformBasicAnimation // swiftlint:disable:this force_cast
    copy.transform = transform
    copy.pivotOffset = pivotOffset
    copy.motion = motion
    return copy
  }
}

/// An anchored transform animation of a spring, from one transform about the point to another.
final class AnchoredTransformSpringAnimation: CASpringAnimation, AnchoredTransformMotionAnimation {

  var transform = CATransform3DIdentity
  var pivotOffset = SIMD2<Double>.zero
  var motion: TransformMotion?

  override func copy(with zone: NSZone? = nil) -> Any {
    // Core Animation copies an animation when it's added, without the Swift properties, so the copy takes them here
    let copy = super.copy(with: zone) as! AnchoredTransformSpringAnimation // swiftlint:disable:this force_cast
    copy.transform = transform
    copy.pivotOffset = pivotOffset
    copy.motion = motion
    return copy
  }
}
