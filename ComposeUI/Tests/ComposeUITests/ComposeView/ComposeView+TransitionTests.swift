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

@_spi(Private) @testable import ComposeUI

class ComposeView_TransitionTests: XCTestCase {

  func test_transitions() {
    // given: a compose view and a transition with captured insertion and removal completions
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

    // when: content with the transition is rendered with animation
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

    // then: before the insertion completion, the pending completion is tracked
    expect(didInsert) == false
    expect(contentView.test.insertingRenderableTransitionCompletionMap.count) == 1

    // when: the insertion completion is called
    insertionCompletion?()

    // then: after the insertion completion, the didInsert is called and the pending completion is untracked
    expect(didInsert) == true
    expect(contentView.test.insertingRenderableTransitionCompletionMap.count) == 0

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: before the removal completion, the renderable is still in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 1

    // when: the removal completion is called
    removalCompletion?()

    // then: after the removal completion, the renderable is removed from the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 0
  }

  func test_delayedTransition_removalCompletesThroughScheduledAnimation() {
    // given: a hosted compose view showing content with a delayed opacity transition
    let window = TestWindow()
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(contentView)

    contentView.setContent {
      ColorNode(.red)
        .transition(.opacity(timing: .linear(duration: 0.1, delay: 0.3)))
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the removal is in flight while the scheduled animation waits out its delay: it must not complete during the
    // delay window
    expect(contentView.test.removingRenderableMap.count) == 1
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    expect(contentView.test.removingRenderableMap.count) == 1

    // then: the scheduled animation's completion finishes the removal after the delay and the duration
    expect(contentView.test.removingRenderableMap.count).toEventually(beEqual(to: 0), timeout: 2)
  }

  func test_reinsertRemovingRenderable() {
    // given: a compose view showing content with a transition that captures its insertion and removal completions
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

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: before the removal completion, the renderable is still in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 1

    // when: reinsert the renderable
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    // then: the renderable is not in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 0

    removalCompletion?()
    insertionCompletion?()
  }

  func test_removeDuringInsertTransition_doesNotCallDidInsert() {
    // given: a compose view showing content with an insert-only transition, the insert transition still in flight
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

    // when: remove the renderable while its insert transition is still in flight
    // the transition has no remove transition, so the renderable is removed (and pooled) immediately.
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the pending insert completion is cancelled
    expect(contentView.test.insertingRenderableTransitionCompletionMap.count) == 0

    // when: the insert transition completes late
    // the renderable is no longer inserted (it may even be pooled or serving a different item by now).
    insertionCompletion?()

    // then: `didInsert` must not be called
    expect(didInsert) == false
  }

  func test_reinsertDuringInsertTransition_staleInsertCompletionIsIgnored() {
    // given: a compose view showing content with an insert-only transition, the first insert transition still in flight
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

    // when: remove the renderable while its insert transition is still in flight, then re-insert it
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    // then: a second insert transition is started
    expect(insertionCompletions.count) == 2

    // when: the first insert transition's completion is called
    insertionCompletions[0]()

    // then: the first completion is stale (its insertion was cancelled by the removal), so it must not call `didInsert`
    expect(didInsertCount) == 0

    // when: the second insert transition's completion is called
    insertionCompletions[1]()

    // then: the second completion is current, so it calls `didInsert`
    expect(didInsertCount) == 1
  }

  func test_reinsertRemovingRenderable_removeTransitionResidueIsReset() {
    // given: a compose view showing content with a residue-leaving remove transition
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var removedLayer: CALayer?
    // a remove transition that leaves presentation residue (a faded-out model opacity and an in-flight animation)
    // and supplies a `resetForReuse` that undoes both.
    let transition = RenderableTransition(
      insert: nil,
      remove: RenderableTransition.RemoveTransition(
        animatedKeyPaths: ["opacity"],
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

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the remove transition is in flight, with its residue on the renderable's layer
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(removedLayer?.opacity) == 0
    expect(removedLayer?.animation(forKey: "fade")) != nil

    // when: an unrelated animation is added and the renderable is re-inserted without animation
    // an animation the transition didn't add, e.g. a persistent content animation owned by the renderable
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    removedLayer?.add(spinAnimation, forKey: "spin")

    // re-inserting the renderable without animation cancels the removal and revives the renderable.
    // there is no insert transition to take over the remove transition's residue, so the revival undoes it via the
    // remove transition's `resetForReuse`: the model opacity is restored and the in-flight remove animation is removed,
    // so the renderable snaps cleanly to its resting state instead of gliding around it.
    // animations the transition didn't add are left alone.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // then: the residue is reset and the unrelated animation is left alone
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(removedLayer?.opacity) == 1
    expect(removedLayer?.animation(forKey: "fade")) == nil
    expect(removedLayer?.animation(forKey: "spin")) != nil
  }

  /// Makes a transition whose removal animates opacity and leaves residue (a faded-out model opacity and an
  /// in-flight "fade" animation) that its `resetForReuse` undoes, paired with an insert transition that doesn't
  /// animate opacity but declares the given taken-over key paths.
  private func makeResidueTransition(takesOverKeyPaths: Set<String>,
                                     removedLayer: @escaping (CALayer) -> Void,
                                     insertTransitionDidRun: @escaping (RenderableTransition.InsertTransition.Context) -> Void) -> RenderableTransition
  {
    RenderableTransition(
      insert: RenderableTransition.InsertTransition(takesOverKeyPaths: takesOverKeyPaths) { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        insertTransitionDidRun(context)
        completion()
      },
      remove: RenderableTransition.RemoveTransition(
        animatedKeyPaths: ["opacity"],
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
          renderable.layer.opacity = 1
        }
      )
    )
  }

  func test_reinsertRemovingRenderable_insertTransitionTakesOver_residueIsLeft() {
    // given: a compose view showing content with a residue-leaving transition whose insert takes over the removal's key path
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var removedLayer: CALayer?
    var insertTransitionRunCount = 0
    var insertContext: RenderableTransition.InsertTransition.Context?
    let transition = makeResidueTransition(
      takesOverKeyPaths: ["opacity"],
      removedLayer: { removedLayer = $0 },
      insertTransitionDidRun: {
        insertTransitionRunCount += 1
        insertContext = $0
      }
    )

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(transition)
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the remove transition is in flight, with its residue on the renderable's layer
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(removedLayer?.opacity) == 0
    expect(removedLayer?.animation(forKey: "fade")) != nil

    // when: re-insert the renderable with animation
    // the removal is cancelled, the renderable is revived, and the insert transition runs. the insert transition takes
    // over every key path the remove transition animates, so the remove transition's residue (the in-flight animation
    // and the faded-out model opacity) is left untouched for it to continue from. this insert transition doesn't touch
    // opacity, so the residue stays.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    // then: the residue stays and the insert transition ran
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(removedLayer?.opacity) == 0
    expect(removedLayer?.animation(forKey: "fade")) != nil
    expect(insertTransitionRunCount) == 1

    // then: a taking-over insert receives the revival position, even when the taken-over residue doesn't animate position
    expect(insertContext?.revivalPosition) == CGPoint(x: 50, y: 50)
  }

  func test_reinsertRemovingRenderable_insertTransitionDoesNotTakeOver_residueIsReset() {
    // given: a compose view showing content with a residue-leaving transition whose insert does not take over the
    // removal's key path
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var removedLayer: CALayer?
    var insertTransitionRunCount = 0
    var insertContext: RenderableTransition.InsertTransition.Context?
    // the insert transition takes over a different key path than the one the remove transition animates,
    // e.g. a slide insert reviving an opacity removal
    let transition = makeResidueTransition(
      takesOverKeyPaths: ["position"],
      removedLayer: { removedLayer = $0 },
      insertTransitionDidRun: {
        insertTransitionRunCount += 1
        insertContext = $0
      }
    )

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(transition)
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the remove transition is in flight, with its residue on the renderable's layer
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(removedLayer?.opacity) == 0
    expect(removedLayer?.animation(forKey: "fade")) != nil

    // when: re-insert the renderable with animation
    // the removal is cancelled, the renderable is revived, and the insert transition runs. the insert transition
    // doesn't take over the removal's animated key path ("opacity"), so the remove transition's `resetForReuse` undoes
    // the residue first and the renderable is fully visible.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    // then: the residue is reset and the insert transition ran
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(removedLayer?.opacity) == 1
    expect(removedLayer?.animation(forKey: "fade")) == nil
    expect(insertTransitionRunCount) == 1

    // then: a reset revival provides no revival position: the insert starts fresh
    expect(insertContext?.revivalPosition) == nil
  }

  func test_reinsertRemovingRenderable_slideTransition_insertComposesWithInFlightRemoval() throws {
    // given: a compose view showing content with a slow slide transition
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.slide(from: .left, timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the remove transition is in flight: a single additive animation sliding the renderable out
    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.basicAnimations(forKeyPath: "position").count) == 1

    // when: revive the renderable with an animated insert
    // the slide insert takes over the in-flight removal by composing additively with it. the leftover remove animation
    // is kept, the insert stacks its own animation on top, and the insert's starting delta exactly compensates the
    // model position change, so the rendered position is continuous at the revival instant.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    // then: the insert animation stacks on the kept remove animation and the rendered position is continuous
    expect(layer.basicAnimations(forKeyPath: "position").count) == 2
    expect(layer.position) == layer.position(from: CGRect(x: 0, y: 0, width: 100, height: 100))
  }

  func test_reinsertRemovingRenderable_crossSideSlideTransition_insertContinuesFromRemovalPosition() throws {
    // given: a compose view showing content with a slow cross-side slide transition
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.slide(from: .left, to: .right, timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the remove transition is in flight, sliding the renderable out to the right: the model position is off-screen
    // right, with a single additive animation holding the rendered position
    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.basicAnimations(forKeyPath: "position").count) == 1
    let removalPosition = layer.position
    expect(removalPosition.x) > 100

    // when: revive the renderable with an animated insert
    // the insert anchors its offset to the removal's model position, so the offset cancels the model change and the
    // rendered position is continuous at the revival instant, even though the transition's entry side differs from its
    // exit side. the leftover exit offset keeps decaying on top.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    // then: the insert animation stacks on the kept remove animation and the rendered position is continuous
    let targetFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let animations = layer.basicAnimations(forKeyPath: "position")
    expect(animations.count) == 2
    expect(layer.position) == layer.position(from: targetFrame)

    // then: the insert's offset starts from the removal's model position, towards the target: the revival re-enters from
    // where the removal left it (the exit side), not from the configured entry side
    let insertAnimation = try unwrap(animations.last)
    expect(insertAnimation.fromValue as? CGPoint) == removalPosition - layer.position(from: targetFrame)
    expect(insertAnimation.toValue as? CGPoint) == .zero
  }

  func test_reinsertRemovingRenderable_crossSideSlideTransition_renderedPositionIsContinuous() throws {
    // given: a hosted compose view showing content with a slow cross-side slide transition
    let window = TestWindow()
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(contentView)

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.slide(from: .left, to: .right, timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation and then revived mid-flight
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)

    // let the removal render, so the presentation is mid-flight
    expect(layer.presentation()).toEventuallyNot(beNil())
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
    let positionBefore = try unwrap(layer.presentation()).position

    // revive mid-flight and let the revival commit
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    let positionAfter = try unwrap(layer.presentation()).position

    // then: the rendered position is continuous at the revival: the 10s linear motion drifts a few points between the
    // samples, far from the content-width jump a restart from the entry side would show
    expect(abs(positionAfter.x - positionBefore.x) < 25) == true
    expect(abs(positionAfter.y - positionBefore.y) < 5) == true
  }

  func test_reinsertRemovingRenderable_opacityTransition_insertRetargetsFromInFlightState() throws {
    // given: a compose view showing content with a slow opacity transition
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.opacity(timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the remove transition is in flight: a single additive animation fading the rendered opacity from 1 towards
    // the model value 0
    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.opacity) == 0
    let removeAnimationKey = try unwrap(
      layer.animationKeys()?.first { (layer.animation(forKey: $0) as? CABasicAnimation)?.keyPath == "opacity" }
    )
    let removeAnimation = try unwrap(layer.animation(forKey: removeAnimationKey) as? CABasicAnimation)

    // when: re-date the in-flight animation to halfway through (so the rendered opacity is 0.5) and revive the
    // renderable with an animated insert
    // the copy shares the original's animation delegate, whose deferred callbacks would fire once per animation
    // instance and trip the delegate's double-callback assertion, so detach it from the copy.
    // removing the original relies on Core Animation deferring `animationDidStop`: a synchronous callback would
    // complete the removal here and detach the renderable before the revival.
    let halfwayAnimation = try unwrap(removeAnimation.copy() as? CABasicAnimation)
    halfwayAnimation.delegate = nil
    halfwayAnimation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - 5
    layer.removeAnimation(forKey: removeAnimationKey)
    layer.add(halfwayAnimation, forKey: removeAnimationKey)

    // the insert transition takes over the in-flight state.
    // the retargeting insert samples the halfway rendered opacity (model 0 plus in-flight contribution 0.5), sets the
    // model to 1 and continues from 0.5 with a single additive animation (from ≈ -0.5 to 0).
    // if the revival had reset the model opacity to 1 before the insert transition ran, the sampled state
    // would clamp to 1 and the animation would start from 0, a visual jump to full opacity.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    // then: the model opacity is restored with a single additive insert animation continuing from the halfway state
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

    // given: a compose view rendering a node id'd "x" (non-fixed) with a remove transition
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

    contentView.setContent {
      ColorNode(.red).id("x").transition(transition)
    }
    contentView.refresh(animated: false)

    // when: remove it
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: with a remove transition, it parks in the removing map under id "x" (non-fixed)
    expect(contentView.test.removingRenderableMap.count) == 1

    // when: re-insert the same string id, but fixed
    contentView.setContent {
      ColorNode(.red).fixedId("x").transition(transition)
    }
    contentView.refresh(animated: true)

    // then: the parked renderable was matched by its string id and revived, despite the isFixed difference
    expect(contentView.test.removingRenderableMap.count) == 0

    removalCompletion?()
  }
}
