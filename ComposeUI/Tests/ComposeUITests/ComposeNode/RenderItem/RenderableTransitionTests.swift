//
//  RenderableTransitionTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/27/26.
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

@testable import ComposeUI

class RenderableTransitionTests: XCTestCase {

  // MARK: - RemoveTransition.resetForReuse

  func test_resetForReuse_removesAnimatedKeyPathAnimations() {
    let transition = RenderableTransition.RemoveTransition(
      animatedKeyPaths: ["opacity"],
      animate: { _, _, _ in }
    )

    let layer = CALayer()
    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 60
    layer.add(fadeAnimation, forKey: "fade")
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // the framework removes the animations of the declared key paths, even without a reset closure,
    // leaving other properties' animations alone
    transition.resetForReuse(renderable: .layer(layer))

    expect(layer.animation(forKey: "fade")) == nil
    expect(layer.animation(forKey: "spin")) != nil
  }

  func test_resetForReuse_runsClosureAfterRemovingAnimations() {
    var animationCountAtClosureTime: Int?
    let transition = RenderableTransition.RemoveTransition(
      animatedKeyPaths: ["opacity"],
      animate: { _, _, _ in },
      resetForReuse: { renderable in
        animationCountAtClosureTime = renderable.layer.basicAnimations(forKeyPath: "opacity").count
      }
    )

    let layer = CALayer()
    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 60
    layer.add(fadeAnimation, forKey: "fade")

    transition.resetForReuse(renderable: .layer(layer))

    // the closure runs after the animations are removed, so it observes the cleaned state
    expect(animationCountAtClosureTime) == 0
  }

  // MARK: - RemoveTransition.isTakenOver(by:)

  private func makeRemoveTransition(animatedKeyPaths: Set<String>?) -> RenderableTransition.RemoveTransition {
    RenderableTransition.RemoveTransition(animatedKeyPaths: animatedKeyPaths, animate: { _, _, _ in })
  }

  private func makeInsertTransition(takesOverKeyPaths: Set<String>) -> RenderableTransition.InsertTransition {
    RenderableTransition.InsertTransition(takesOverKeyPaths: takesOverKeyPaths) { _, _, _ in }
  }

  func test_isTakenOver_coveredFootprint() {
    let removeTransition = makeRemoveTransition(animatedKeyPaths: ["opacity"])

    // a fully covered footprint is taken over, including by an insert transition that takes over more
    expect(removeTransition.isTakenOver(by: makeInsertTransition(takesOverKeyPaths: ["opacity"]))) == true
    expect(removeTransition.isTakenOver(by: makeInsertTransition(takesOverKeyPaths: ["opacity", "position"]))) == true
  }

  func test_isTakenOver_uncoveredFootprint() {
    // a partially covered footprint is not taken over
    let removeTransition = makeRemoveTransition(animatedKeyPaths: ["opacity", "position"])
    expect(removeTransition.isTakenOver(by: makeInsertTransition(takesOverKeyPaths: ["position"]))) == false

    // a mismatched footprint is not taken over
    expect(makeRemoveTransition(animatedKeyPaths: ["opacity"]).isTakenOver(by: makeInsertTransition(takesOverKeyPaths: ["position"]))) == false
  }

  func test_isTakenOver_unknownFootprint() {
    // an unknown footprint is never taken over
    let removeTransition = makeRemoveTransition(animatedKeyPaths: nil)
    expect(removeTransition.isTakenOver(by: makeInsertTransition(takesOverKeyPaths: ["opacity"]))) == false
  }

  func test_isTakenOver_emptyFootprint() {
    // an empty footprint has nothing to continue, so it is not taken over (the reset is harmless for it)
    let removeTransition = makeRemoveTransition(animatedKeyPaths: [])
    expect(removeTransition.isTakenOver(by: makeInsertTransition(takesOverKeyPaths: ["opacity"]))) == false
  }

  func test_isTakenOver_noInsertTransition() {
    let removeTransition = makeRemoveTransition(animatedKeyPaths: ["opacity"])
    expect(removeTransition.isTakenOver(by: nil)) == false
  }
}
