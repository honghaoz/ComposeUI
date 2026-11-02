//
//  AnimationsTests.swift
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

class AnimationsTests: XCTestCase {

  func test_preferredFrameRateRange() throws {
    guard #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) else {
      throw XCTSkip("frame rate ranges are available from macOS 12, iOS 15 and tvOS 15")
    }

    // then: the animations ask for 80 to 120 Hz, preferring 120 Hz, by default
    expect(Animations.preferredFrameRateRange) == CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)

    // when: setting another range
    let originalRange = Animations.preferredFrameRateRange
    defer {
      Animations.preferredFrameRateRange = originalRange
    }
    let lowerRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    Animations.preferredFrameRateRange = lowerRange

    // then: the animations ask for it
    expect(Animations.preferredFrameRateRange) == lowerRange
  }

  func test_preferredFrameRateRange_setOffTheMainThread_asserts() throws {
    guard #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) else {
      throw XCTSkip("frame rate ranges are available from macOS 12, iOS 15 and tvOS 15")
    }

    // given: a test assertion failure handler
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    let originalRange = Animations.preferredFrameRateRange
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
      Animations.preferredFrameRateRange = originalRange
    }

    // when: setting the range on another thread
    onNewThread {
      Animations.preferredFrameRateRange = .default
    }

    // then: it asserts that the range is set on the main thread
    expect(assertionMessages) == ["preferredFrameRateRange must be set on the main thread"]
  }
}
