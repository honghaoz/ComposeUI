//
//  AnimationDelegateTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
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

import ChouTiTest

@testable import ComposeUI

class AnimationDelegateTests: XCTestCase {

  func test() {
    let layer = CALayer()

    var didStartCount = 0
    var didStopCount = 0

    let delegate = AnimationDelegate(
      animationDidStart: { animation in
        didStartCount += 1
      },
      animationDidStop: { animation, finished in
        didStopCount += 1
      }
    )

    let animation = CABasicAnimation()
    animation.keyPath = "position"
    animation.fromValue = CGPoint(x: 0, y: 0)
    animation.toValue = CGPoint(x: 100, y: 100)
    animation.duration = 0.01
    animation.delegate = delegate

    layer.add(animation, forKey: "position")

    expect(didStartCount) == 0
    expect(didStopCount) == 0

    expect(didStartCount).toEventually(beEqual(to: 1))
    expect(didStopCount).toEventually(beEqual(to: 1))

    delegate.animationDidStart(animation)
    delegate.animationDidStop(animation, finished: true)

    expect(didStartCount) == 1
    expect(didStopCount) == 1
  }
}
