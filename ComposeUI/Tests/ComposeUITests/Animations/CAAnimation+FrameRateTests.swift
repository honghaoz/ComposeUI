//
//  CAAnimation+FrameRateTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/2/26.
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

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class CAAnimation_FrameRateTests: XCTestCase {

  func test_applyPreferredFrameRateRange() throws {
    guard #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) else {
      throw XCTSkip("frame rate ranges are available from macOS 12, iOS 15 and tvOS 15")
    }

    // given: an animation without a frame rate range
    let animation = CAKeyframeAnimation(keyPath: "opacity")
    expect(animation.preferredFrameRateRange) == .default

    // when: applying the preferred frame rate range of ComposeUI's animations
    animation.applyPreferredFrameRateRange()

    // then: the animation asks for the default range, 80 to 120 Hz, preferring 120 Hz
    expect(animation.preferredFrameRateRange) == CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
  }

  func test_applyPreferredFrameRateRange_lowerRange() throws {
    guard #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) else {
      throw XCTSkip("frame rate ranges are available from macOS 12, iOS 15 and tvOS 15")
    }

    // given: a lower preferred frame rate range
    let originalRange = Animations.preferredFrameRateRange
    defer {
      Animations.preferredFrameRateRange = originalRange
    }
    let lowerRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    Animations.preferredFrameRateRange = lowerRange

    // when: applying it to an animation
    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.applyPreferredFrameRateRange()

    // then: the animation asks for the lower range
    expect(animation.preferredFrameRateRange) == lowerRange
  }

  func test_applyPreferredFrameRateRange_defaultRange_leavesTheAnimationsRange() throws {
    guard #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) else {
      throw XCTSkip("frame rate ranges are available from macOS 12, iOS 15 and tvOS 15")
    }

    // given: the default range, which leaves the rate to Core Animation, and an animation that asks for 60 Hz
    let originalRange = Animations.preferredFrameRateRange
    defer {
      Animations.preferredFrameRateRange = originalRange
    }
    Animations.preferredFrameRateRange = .default
    let fixedRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.preferredFrameRateRange = fixedRange

    // when: applying the default range
    animation.applyPreferredFrameRateRange()

    // then: the default range isn't set, so the animation keeps its range
    expect(animation.preferredFrameRateRange) == fixedRange
  }
}
