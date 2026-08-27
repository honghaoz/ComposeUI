//
//  ComposeView+TransitionTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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

class ComposeView_TransitionTests: XCTestCase {

  func test_transitions() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var insertionCompletion: (() -> Void)?
    var removalCompletion: (() -> Void)?
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        insertionCompletion = completion
      },
      remove: RenderableTransition.RemoveTransition { renderable, context, completion in
        removalCompletion = completion
      }
    )

    var didInsert = false
    contentView.setContent {
      ColorNode(.red)
        .onInsert { _, _ in
          didInsert = true
        }
        .transition(transition)
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    // before the insertion completion, the pending completion is tracked
    expect(didInsert) == false
    expect(contentView.test.insertingRenderableTransitionCompletionMap.count) == 1

    insertionCompletion?()

    // after the insertion completion, the didInsert is called and the pending completion is untracked
    expect(didInsert) == true
    expect(contentView.test.insertingRenderableTransitionCompletionMap.count) == 0

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // before the removal completion, the renderable is still in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 1

    removalCompletion?()

    // after the removal completion, the renderable is removed from the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 0
  }

  func test_reinsertRemovingRenderable() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var insertionCompletion: (() -> Void)?
    var removalCompletion: (() -> Void)?
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        insertionCompletion = completion
      },
      remove: RenderableTransition.RemoveTransition { renderable, context, completion in
        removalCompletion = completion
      }
    )

    contentView.setContent {
      ColorNode(.red)
        .transition(transition)
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // before the removal completion, the renderable is still in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 1

    // reinsert the renderable
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    // the renderable is not in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 0

    removalCompletion?()
    insertionCompletion?()
  }

  func test_removeDuringInsertTransition_doesNotCallDidInsert() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var insertionCompletion: (() -> Void)?
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        insertionCompletion = completion
      },
      remove: nil
    )

    var didInsert = false
    contentView.setContent {
      ColorNode(.red)
        .onInsert { _, _ in
          didInsert = true
        }
        .transition(transition)
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)
    expect(didInsert) == false
    expect(contentView.test.insertingRenderableTransitionCompletionMap.count) == 1

    // remove the renderable while its insert transition is still in flight,
    // the transition has no remove transition, so the renderable is removed (and pooled) immediately.
    // the pending insert completion should be cancelled.
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)
    expect(contentView.test.insertingRenderableTransitionCompletionMap.count) == 0

    // the insert transition completes late, the renderable is no longer inserted (it may even be pooled
    // or serving a different item by now), so `didInsert` must not be called.
    insertionCompletion?()
    expect(didInsert) == false
  }

  func test_reinsertDuringInsertTransition_staleInsertCompletionIsIgnored() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var insertionCompletions: [() -> Void] = []
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        insertionCompletions.append(completion)
      },
      remove: nil
    )

    var didInsertCount = 0
    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .onInsert { _, _ in
          didInsertCount += 1
        }
        .transition(transition)
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)
    expect(insertionCompletions.count) == 1

    // remove the renderable while its insert transition is still in flight, then re-insert it,
    // which starts a second insert transition.
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)
    expect(insertionCompletions.count) == 2

    // the first insert transition's completion is stale (its insertion was cancelled by the removal),
    // so it must not call `didInsert`.
    insertionCompletions[0]()
    expect(didInsertCount) == 0

    // the second insert transition's completion is current, so it calls `didInsert`.
    insertionCompletions[1]()
    expect(didInsertCount) == 1
  }

  func test_reinsertRemovingRenderable_removeTransitionResidueIsReset() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var removedLayer: CALayer?
    // a remove transition that leaves presentation residue (a faded-out model opacity and an in-flight animation)
    // and supplies a `resetForReuse` that undoes both.
    let transition = RenderableTransition(
      insert: nil,
      remove: RenderableTransition.RemoveTransition(
        animate: { renderable, _, _ in
          renderable.layer.opacity = 0
          // an explicit duration so that the animation isn't completed (and removed) immediately by the render
          // pass's zero-duration transaction.
          let animation = CABasicAnimation(keyPath: "opacity")
          animation.duration = 1
          renderable.layer.add(animation, forKey: "fade")
          removedLayer = renderable.layer
        },
        resetForReuse: { renderable in
          renderable.layer.removeAnimation(forKey: "fade")
          renderable.layer.opacity = 1
        }
      )
    )

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(transition)
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // the remove transition is in flight, with its residue on the renderable's layer
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(removedLayer?.opacity) == 0
    expect(removedLayer?.animation(forKey: "fade")) != nil

    // an animation the transition didn't add, e.g. a persistent content animation owned by the renderable
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    removedLayer?.add(spinAnimation, forKey: "spin")

    // re-insert the renderable without animation: the removal is cancelled and the renderable is revived.
    // there is no insert transition to take over the remove transition's residue, so the revival undoes it via the
    // remove transition's `resetForReuse`: the model opacity is restored and the in-flight remove animation is removed,
    // so the renderable snaps cleanly to its resting state instead of gliding around it.
    // animations the transition didn't add are left alone.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    expect(contentView.test.removingRenderableMap.count) == 0
    expect(removedLayer?.opacity) == 1
    expect(removedLayer?.animation(forKey: "fade")) == nil
    expect(removedLayer?.animation(forKey: "spin")) != nil
  }

  /// Makes a transition whose removal leaves residue (a faded-out model opacity and an in-flight "fade" animation)
  /// that its `resetForReuse` undoes, paired with an insert transition that doesn't animate opacity.
  private func makeResidueTransition(takesOverInFlightRemoval: Bool,
                                     removedLayer: @escaping (CALayer) -> Void,
                                     insertTransitionDidRun: @escaping () -> Void) -> RenderableTransition
  {
    RenderableTransition(
      insert: RenderableTransition.InsertTransition(takesOverInFlightRemoval: takesOverInFlightRemoval) { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        insertTransitionDidRun()
        completion()
      },
      remove: RenderableTransition.RemoveTransition(
        animate: { renderable, _, _ in
          renderable.layer.opacity = 0
          // an explicit duration so that the animation isn't completed (and removed) immediately by the render pass's
          // zero-duration transaction.
          let animation = CABasicAnimation(keyPath: "opacity")
          animation.duration = 1
          renderable.layer.add(animation, forKey: "fade")
          removedLayer(renderable.layer)
        },
        resetForReuse: { renderable in
          renderable.layer.removeAnimation(forKey: "fade")
          renderable.layer.opacity = 1
        }
      )
    )
  }

  func test_reinsertRemovingRenderable_insertTransitionTakesOver_residueIsLeft() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var removedLayer: CALayer?
    var insertTransitionRunCount = 0
    let transition = makeResidueTransition(
      takesOverInFlightRemoval: true,
      removedLayer: { removedLayer = $0 },
      insertTransitionDidRun: { insertTransitionRunCount += 1 }
    )

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(transition)
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // the remove transition is in flight, with its residue on the renderable's layer
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(removedLayer?.opacity) == 0
    expect(removedLayer?.animation(forKey: "fade")) != nil

    // re-insert the renderable with animation: the removal is cancelled, the renderable is revived, and the insert
    // transition runs. the insert transition declares the takeover, so the remove transition's residue (the in-flight
    // animation and the faded-out model opacity) is left untouched for it to continue from. this insert transition
    // doesn't touch opacity, so the residue stays.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    expect(contentView.test.removingRenderableMap.count) == 0
    expect(removedLayer?.opacity) == 0
    expect(removedLayer?.animation(forKey: "fade")) != nil
    expect(insertTransitionRunCount) == 1
  }

  func test_reinsertRemovingRenderable_insertTransitionDoesNotTakeOver_residueIsReset() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var removedLayer: CALayer?
    var insertTransitionRunCount = 0
    let transition = makeResidueTransition(
      takesOverInFlightRemoval: false,
      removedLayer: { removedLayer = $0 },
      insertTransitionDidRun: { insertTransitionRunCount += 1 }
    )

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(transition)
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // the remove transition is in flight, with its residue on the renderable's layer
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(removedLayer?.opacity) == 0
    expect(removedLayer?.animation(forKey: "fade")) != nil

    // re-insert the renderable with animation: the removal is cancelled, the renderable is revived, and the insert
    // transition runs. the insert transition doesn't take over the in-flight removal (it doesn't animate opacity),
    // so the remove transition's `resetForReuse` undoes the residue first and the renderable is fully visible.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    expect(contentView.test.removingRenderableMap.count) == 0
    expect(removedLayer?.opacity) == 1
    expect(removedLayer?.animation(forKey: "fade")) == nil
    expect(insertTransitionRunCount) == 1
  }

  func test_reinsertRemovingRenderable_opacityTransition_insertRetargetsFromInFlightState() throws {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.opacity(timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // the remove transition is in flight: a single additive animation fading the rendered opacity from 1 towards the
    // model value 0.
    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.opacity) == 0
    let removeAnimationKey = try unwrap(
      layer.animationKeys()?.first { (layer.animation(forKey: $0) as? CABasicAnimation)?.keyPath == "opacity" }
    )
    let removeAnimation = try unwrap(layer.animation(forKey: removeAnimationKey) as? CABasicAnimation)

    // re-date the in-flight animation to halfway through, so the rendered opacity is 0.5.
    // the copy shares the original's animation delegate, whose deferred callbacks would fire once per animation
    // instance and trip the delegate's double-callback assertion, so detach it from the copy.
    let halfwayAnimation = try unwrap(removeAnimation.copy() as? CABasicAnimation)
    halfwayAnimation.delegate = nil
    halfwayAnimation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - 5
    layer.removeAnimation(forKey: removeAnimationKey)
    layer.add(halfwayAnimation, forKey: removeAnimationKey)

    // revive the renderable with an animated insert: the insert transition takes over the in-flight state.
    // the retargeting insert samples the halfway rendered opacity (model 0 plus in-flight contribution 0.5), sets the
    // model to 1 and continues from 0.5 with a single additive animation (from ≈ -0.5 to 0).
    // if the revival had reset the model opacity to 1 before the insert transition ran, the sampled state
    // would clamp to 1 and the animation would start from 0, a visual jump to full opacity.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    expect(layer.opacity) == 1

    let opacityAnimations = layer.basicAnimations(forKeyPath: "opacity")
    expect(opacityAnimations.count) == 1

    let insertAnimation = try unwrap(opacityAnimations.first)
    expect(insertAnimation.isAdditive) == true
    expect(try unwrap(insertAnimation.fromValue as? Float)).to(beApproximatelyEqual(to: -0.5, within: 0.05))
    expect(insertAnimation.toValue as? Float) == 0

    expect(contentView.test.removingRenderableMap.count) == 0
  }

  func test_reinsertRemovingRenderable_ignoresIsFixed() {
    // Like `test_reinsertRemovingRenderable`, but the renderable is re-inserted with a *fixed* id of the same string.
    // Render identity is the id string only (ignoring isFixed), so the re-inserted item must match the renderable
    // parked in `removingRenderableMap` (keyed by that same string) and cancel its removal, not leave it stranded and
    // create a new one.
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var removalCompletion: (() -> Void)?
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        completion()
      },
      remove: RenderableTransition.RemoveTransition { _, _, completion in
        removalCompletion = completion
      }
    )

    // render a node id'd "x" (non-fixed)
    contentView.setContent {
      ColorNode(.red).id("x").transition(transition)
    }
    contentView.refresh(animated: false)

    // remove it -> with a remove transition, it parks in the removing map under id "x" (non-fixed)
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)
    expect(contentView.test.removingRenderableMap.count) == 1

    // re-insert the same string id, but FIXED
    contentView.setContent {
      ColorNode(.red).fixedId("x").transition(transition)
    }
    contentView.refresh(animated: true)

    // the parked renderable was matched by its string id and revived, despite the isFixed difference
    expect(contentView.test.removingRenderableMap.count) == 0

    removalCompletion?()
  }
}
