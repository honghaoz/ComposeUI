//
//  AnimationDelegateTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
//

import ChouTiTest

@testable import ComposeUI

class AnimationDelegateTests: XCTestCase {

  func test() throws {
    let didStartExpectation = expectation(description: "didStart")
    didStartExpectation.assertForOverFulfill = true
    let didStopExpectation = expectation(description: "didStop")
    didStopExpectation.assertForOverFulfill = true

    let animation = CABasicAnimation(keyPath: "backgroundColor")
    animation.fromValue = Color.red.cgColor
    animation.toValue = Color.blue.cgColor
    animation.duration = 0.1
    animation.delegate = AnimationDelegate(
      animationDidStart: { animation in
        didStartExpectation.fulfill()
      },
      animationDidStop: { animation, finished in
        if finished {
          didStopExpectation.fulfill()
        }
      }
    )

    let window = TestWindow()

    let layer = CALayer()
    layer.backgroundColor = Color.red.cgColor

    window.layer.addSublayer(layer)

    layer.add(animation, forKey: "backgroundColor")

    wait(for: [didStartExpectation, didStopExpectation], timeout: 0.5)
  }

  func test_redundantCalls() {
    let animation = CABasicAnimation(keyPath: "backgroundColor")

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

    delegate.animationDidStart(animation)
    delegate.animationDidStop(animation, finished: true)

    expect(didStartCount) == 1
    expect(didStopCount) == 1

    // redundant calls

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, file, line, column in
      switch assertionCount {
      case 0:
        expect(message) == "animation already started: \(animation)"
      case 1:
        expect(message) == "animation already stopped: \(animation)"
      default:
        fail("unexpected assertion")
      }

      assertionCount += 1
    }

    delegate.animationDidStart(animation)
    delegate.animationDidStop(animation, finished: true)

    expect(didStartCount) == 1
    expect(didStopCount) == 1

    Assert.resetTestAssertionFailureHandler()
  }
}
