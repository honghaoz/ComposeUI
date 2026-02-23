//
//  CASpringAnimation+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
//

import ChouTiTest

@testable import ComposeUI

class CASpringAnimation_ExtensionsTests: XCTestCase {

  func test_perceptualDuration() {
    let animation = CASpringAnimation()
    animation.mass = 1
    animation.stiffness = 1
    animation.damping = 1
    animation.initialVelocity = 0.1
    expect(animation.perceptualDuration()) == 11.35608158495006
  }

  func test_durationForEpsilon() {
    let animation = CASpringAnimation()
    animation.mass = 1
    animation.stiffness = 1
    animation.damping = 1
    animation.initialVelocity = 0.1
    expect(animation.duration(epsilon: 0.1)) == 5.364617037842078
  }
}
