//
//  RenderItem+ContextTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/8/26.
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

class RenderItem_ContextTests: XCTestCase {

  func test_equality_ignoresInternalAnimationPolicyWhenTimingMatches() {
    // given: matching public update inputs with every internal policy combination
    let frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    for updateType in [RenderableUpdateType.insert, .refresh, .boundsChange] {
      let reference = RenderableUpdateContext(updateType: updateType, oldFrame: frame, newFrame: frame, previousRenderBounds: frame, renderBounds: frame, animationTiming: nil, contentView: nil, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
      for transitions in [false, true] {
        for updates in [false, true] {
          let decision = ComposeView.AnimationDecision(allowsTransitions: transitions, allowsAnimations: updates)
          let context = RenderableUpdateContext(updateType: updateType, oldFrame: frame, newFrame: frame, previousRenderBounds: frame, renderBounds: frame, animationTiming: nil, contentView: nil, contentEvaluation: nil, animationDecision: decision)

          // then: policy metadata does not change the public timing instruction or equality
          expect(context.animationTiming) == nil
          expect(context) == reference
        }
      }
    }
  }

  func test_updateContext_equalityPreservesPublicFields() {
    // given: contexts with identical public values and different internal evaluations
    let view = ComposeView()
    let otherView = ComposeView()
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let noAnimations = ComposeView.AnimationDecision.disabled
    let base = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: noAnimations)
    let first = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: ContentEvaluation(), animationDecision: noAnimations)
    let second = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: ContentEvaluation(), animationDecision: noAnimations)

    let transitionsOnly = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.transitionsOnly)
    let neither = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)

    // then: internal ownership and inherited decisions do not change public equality
    expect(base) == first
    expect(first) == second
    expect(base) == transitionsOnly
    expect(transitionsOnly) == neither

    // given: missing history differs from completed zero bounds
    let withoutHistory = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: nil, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: noAnimations)
    let sameWithoutHistory = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: nil, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: noAnimations)

    // then: equality preserves the distinction
    expect(withoutHistory) == sameWithoutHistory
    expect(base) != withoutHistory

    // given: each public field can independently differ
    let differentContexts = [
      RenderableUpdateContext(updateType: .insert, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: noAnimations),
      RenderableUpdateContext(updateType: .refresh, oldFrame: frame, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: noAnimations),
      RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: noAnimations),
      RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: frame, renderBounds: frame, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: noAnimations),
      RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: nil, contentView: view, contentEvaluation: nil, animationDecision: noAnimations),
      RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: .linear(), contentView: view, contentEvaluation: nil, animationDecision: noAnimations),
      RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: otherView, contentEvaluation: nil, animationDecision: noAnimations),
      RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: frame, previousRenderBounds: .zero, renderBounds: frame, animationTiming: nil, contentView: nil, contentEvaluation: nil, animationDecision: noAnimations),
    ]

    // then: every public difference remains observable through equality
    for context in differentContexts {
      expect(base) != context
    }
  }
}
