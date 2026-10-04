//
//  FrameAnimation.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

/// An additive animation of a layer's frame, from `CALayer.animateFrame(to:timing:)` or a frame retarget, which a frame
/// retarget folds, leaving the other animations of `position` and `bounds.size`, such as a slide transition's, alone.
///
/// The part is a stored property of the animation's class, as a key-value mark on an animation costs about as much as
/// making the animation.
protocol FrameAnimation: CABasicAnimation {

  /// The part of the frame the animation animates.
  var part: FrameAnimationPart { get set }
}

/// The part of a layer's frame that a frame animation animates.
///
/// The position moves with the size by the anchor point times its change, so a `position` animation's offset is the
/// origin's part plus the size's share, which a frame retarget folds apart.
enum FrameAnimationPart: Equatable {

  /// The size, for an animation of `bounds.size`.
  case size

  /// The origin, for an animation of `position` whose offset is all the origin's.
  case origin

  /// The size's share of the position, for an animation of `position` whose offset is all the size's share.
  case sizeShare

  /// Both, for an animation of `position` whose offset has the origin's part and the size's share.
  case originAndSizeShare(originPart: SIMD2<Double>)
}

/// A frame animation of a timing function.
final class FrameBasicAnimation: CABasicAnimation, FrameAnimation {

  var part: FrameAnimationPart = .size

  override func copy(with zone: NSZone? = nil) -> Any {
    // Core Animation copies an animation when it's added, without the Swift property, so the copy takes it here
    let copy = super.copy(with: zone) as! FrameBasicAnimation // swiftlint:disable:this force_cast
    copy.part = part
    return copy
  }
}

/// A frame animation of a spring.
final class FrameSpringAnimation: CASpringAnimation, FrameAnimation {

  var part: FrameAnimationPart = .size

  override func copy(with zone: NSZone? = nil) -> Any {
    // Core Animation copies an animation when it's added, without the Swift property, so the copy takes it here
    let copy = super.copy(with: zone) as! FrameSpringAnimation // swiftlint:disable:this force_cast
    copy.part = part
    return copy
  }
}
