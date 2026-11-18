//
//  ComposeView+ResizeAnimationTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/26.
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

class ComposeView_ResizeAnimationTests: XCTestCase {

  #if canImport(UIKit)

  func test_animatedLayout_followingAnimationsBeginAtTheCommit() throws {
    // given: a row whose update animates its corner radius with the update's timing
    var row: CALayer?
    var item: CALayer?
    var width: CGFloat = 100
    let view = ComposeView {
      LayerNode<CALayer>(update: { layer, context in
        if let timing = context.animationTiming {
          layer.animate(keyPath: "cornerRadius", to: context.newFrame.width / 10, timing: timing)
        }
      })
      .frame(width: .flexible, height: 50)
      .onUpdate { renderable, _ in
        row = renderable.layer
      }
      ColorNode(.blue)
        .frame(width: width, height: 50)
        .animation(.linear(duration: 10))
        .onUpdate { renderable, _ in
          item = renderable.layer
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    view.refresh(animated: false)
    let rowLayer = try unwrap(row)

    // when: resizing the view with a layout in an animation block
    UIView.animate(withDuration: 0.5) {
      view.frame.size.width = 300
      view.layoutIfNeeded()
    }

    // then: the row's animations begin at the commit, as UIKit's resize animation of the view does, and the clock is
    // back to its own begin times after the pass
    let rowAnimations = (rowLayer.animationKeys() ?? []).compactMap { rowLayer.animation(forKey: $0) }
    expect(rowAnimations.count) == 3
    for animation in rowAnimations {
      expect(animation.beginTime) == 0
    }
    expect(AnimationClock.beginsAtCommit) == false
    rowLayer.removeAllAnimations()
    item?.removeAllAnimations()
    view.layer.removeAllAnimations()

    // when: an animated refresh resizes an item, which doesn't follow a resize of UIKit's
    width = 50
    view.refresh(animated: true)

    // then: its animations begin at the animation clock's time
    let itemLayer = try unwrap(item)
    let itemAnimations = (itemLayer.animationKeys() ?? []).compactMap { itemLayer.animation(forKey: $0) }
    expect(itemAnimations.isEmpty) == false
    for animation in itemAnimations {
      expect(animation.beginTime) != 0
    }
    itemLayer.removeAllAnimations()
  }

  func test_animatedLayout_opensACommitWindowUntilUIKitsResizeCommits() throws {
    // given: a view showing a row, and a layer outside it
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 50)
    }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    view.refresh(animated: false)
    let otherLayer = CALayer()

    // when: resizing the view with a layout in an animation block, then animating the other layer before the commit
    UIView.animate(withDuration: 0.5) {
      view.frame.size.width = 300
      view.layoutIfNeeded()
    }
    otherLayer.animate(keyPath: "opacity", to: 0.5, timing: .linear(duration: 1))

    // then: the other layer's animation begins at the commit too, as it commits with UIKit's resize
    expect(try unwrap(otherLayer.animation(forKey: "opacity")).beginTime) == 0
    otherLayer.removeAllAnimations()

    // when: UIKit's resize animation is gone, then the other layer animates again
    view.layer.removeAllAnimations()
    otherLayer.animate(keyPath: "opacity", to: 1, timing: .linear(duration: 1))

    // then: the window is closed, so the animation begins at the clock's time
    expect(try unwrap(otherLayer.animation(forKey: "opacity")).beginTime) != 0
    otherLayer.removeAllAnimations()
  }

  func test_animatedLayout_combinedResize_keepsTheWindowOpenWhileEitherAnimationWaits() throws {
    // given: a view showing a row
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 50)
    }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    view.refresh(animated: false)

    // when: resizing the view in two blocks of the same timing, the second with a layout, then removing one of UIKit's
    // two animations
    UIView.animate(withDuration: 0.5) {
      view.frame.size.width = 250
    }
    UIView.animate(withDuration: 0.5) {
      view.frame.size.width = 300
      view.layoutIfNeeded()
    }
    let sizeKeys = (view.layer.animationKeys() ?? []).filter { (view.layer.animation(forKey: $0) as? CABasicAnimation)?.keyPath == "bounds.size" }
    expect(sizeKeys.count) == 2
    try view.layer.removeAnimation(forKey: unwrap(sizeKeys.last))

    // then: the window stays open for the other animation
    expect(AnimationClock.addsAtCommit) == true

    // when: the second animation goes too
    view.layer.removeAllAnimations()

    // then: the window closes
    expect(AnimationClock.addsAtCommit) == false
  }

  func test_animatedLayout_nestedViewFollowsTheParentsResize_atTheCommit() throws {
    // given: a nested view filling its parent, showing a row
    var row: CALayer?
    var nestedView: ComposeView?
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 50)
          .onUpdate { renderable, _ in
            row = renderable.layer
          }
      }
      .onInsert { renderable, _ in
        nestedView = renderable.view as? ComposeView
      }
    }
    parent.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    parent.refresh(animated: false)
    let rowLayer = try unwrap(row)

    // when: resizing the parent with a layout in an animation block
    UIView.animate(withDuration: 0.5) {
      parent.frame.size.width = 300
      parent.layoutIfNeeded()
    }

    // then: the nested view's frame animation and its row's begin at the commit, with UIKit's
    let nested = try unwrap(nestedView).layer
    for layer in [rowLayer, nested] {
      let animations = (layer.animationKeys() ?? []).compactMap { layer.animation(forKey: $0) }
      expect(animations.isEmpty) == false
      for animation in animations {
        expect(animation.beginTime) == 0
      }
      layer.removeAllAnimations()
    }
    parent.layer.removeAllAnimations()
  }

  func test_animatedLayout_reusedRenderablesFollowTheResize() throws {
    let blockTiming = AnimationTiming(timing: .timingFunction(0.7, CAMediaTimingFunction(name: .easeIn)))
    let ownTiming = AnimationTiming.linear(duration: 10)
    let cases: [(String, ComposeView.AnimationBehavior, AnimationTiming?)] = [
      ("default", .default, blockTiming),
      ("dynamic animating", .dynamic { _, _ in true }, blockTiming),
      ("dynamic not animating", .dynamic { _, _ in false }, nil),
      ("disabled", .disabled, nil),
    ]
    for (name, behavior, expectedTiming) in cases {
      // given: a row with its own update animation, and a row that only shows at a larger width
      var layers: [Int: CALayer] = [:]
      var contexts: [Int: RenderableUpdateContext] = [:]
      let view = ComposeView {
        HStack(spacing: 0) {
          ColorNode(.red)
            .frame(width: .flexible, height: 50)
            .animation(ownTiming)
            .onUpdate { renderable, context in
              layers[0] = renderable.layer
              contexts[0] = context
            }
          ColorNode(.blue)
            .frame(width: 100, height: 50)
            .onUpdate { renderable, context in
              layers[1] = renderable.layer
              contexts[1] = context
            }
        }
      }
      view.animationBehavior = behavior
      view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
      view.refresh(animated: false)
      let row = try unwrap(layers[0])

      // when: resizing the view with a layout in an animation block
      UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseIn) {
        view.frame.size.width = 300
        view.layoutIfNeeded()
      }

      // then: the reused row follows the block's timing in place of its own, unless the behavior disables animations
      expect(contexts[0]?.updateType, name) == .boundsChange
      expect(contexts[0]?.animationTiming, name) == expectedTiming
      expect(row.frame, name) == CGRect(x: 0, y: 25, width: 200, height: 50)
      let sizeAnimation = row.animationKeys()?.lazy.compactMap { row.animation(forKey: $0) as? CABasicAnimation }.first { $0.keyPath == "bounds.size" }
      expect(sizeAnimation?.duration, name) == expectedTiming.map { _ in 0.7 }
      expect(sizeAnimation?.timingFunction, name) == expectedTiming.map { _ in CAMediaTimingFunction(name: .easeIn) }
      row.removeAllAnimations()
      view.layer.removeAllAnimations()
    }
  }

  func test_animatedLayout_pendingRefreshFollowsTheResize() throws {
    let blockTiming = AnimationTiming(timing: .timingFunction(0.5, CAMediaTimingFunction(name: .easeInEaseOut)))
    for (isAnimated, expectedTiming) in [(true, blockTiming), (false, nil)] {
      // given: a row with its own update animation, with a refresh pending
      var context: RenderableUpdateContext?
      let view = ComposeView {
        ColorNode(.red)
          .frame(width: .flexible, height: 50)
          .animation(.linear(duration: 10))
          .onUpdate { _, update in
            context = update
          }
      }
      view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
      view.refresh(animated: false)
      view.setNeedsRefresh(animated: isAnimated)

      // when: resizing the view with a layout in an animation block, which performs the refresh
      UIView.animate(withDuration: 0.5) {
        view.frame.size.width = 300
        view.layoutIfNeeded()
      }

      // then: an animated refresh follows the resize, and a non-animated one stays non-animated
      expect(context?.updateType, "animated \(isAnimated)") == .refresh
      expect(context?.animationTiming, "animated \(isAnimated)") == expectedTiming
      expect(context?.newFrame.width, "animated \(isAnimated)") == 300
      view.layer.removeAllAnimations()
    }
  }

  func test_animatedLayout_nestedViewWithPendingRefreshFollowsTheParentsResize() throws {
    // given: a nested view filling its parent, showing a row, with a refresh pending
    var context: RenderableUpdateContext?
    var nested: ComposeView?
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 50)
          .onUpdate { _, update in
            context = update
          }
      }
      .onInsert { renderable, _ in
        nested = renderable.view as? ComposeView
      }
    }
    parent.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    parent.refresh(animated: false)
    try unwrap(nested).setNeedsRefresh()

    // when: resizing the parent with a layout in an animation block
    UIView.animate(withDuration: 0.5) {
      parent.frame.size.width = 300
      parent.layoutIfNeeded()
    }

    // then: the nested row follows the parent's resize
    expect(context?.updateType) == .refresh
    expect(context?.animationTiming) == AnimationTiming(timing: .timingFunction(0.5, CAMediaTimingFunction(name: .easeInEaseOut)))
    expect(context?.newFrame.width) == 300
    parent.layer.removeAllAnimations()
  }

  func test_animatedLayout_parentPendingRefresh_nestedNodeFollowsTheResize() throws {
    // given: a nested view node filling its parent, showing a row, with an animated refresh pending on the parent
    var context: RenderableUpdateContext?
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 50)
          .onUpdate { _, update in
            context = update
          }
      }
    }
    parent.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    parent.refresh(animated: false)
    parent.setNeedsRefresh(animated: true)

    // when: resizing the parent with a layout in an animation block, which performs the refresh
    UIView.animate(withDuration: 0.5) {
      parent.frame.size.width = 300
      parent.layoutIfNeeded()
    }

    // then: the refresh that the node's update performs follows the parent's resize
    expect(context?.updateType) == .refresh
    expect(context?.animationTiming) == AnimationTiming(timing: .timingFunction(0.5, CAMediaTimingFunction(name: .easeInEaseOut)))
    expect(context?.newFrame.width) == 300
    parent.layer.removeAllAnimations()
  }

  func test_animatedLayout_duringAnotherRenderPass_doesNotFollowTheResizeAfterThePass() throws {
    // given: a view showing a row, resized in an animation block, and another view whose render pass lays it out in an
    // animation block. a render pass disables actions, so the resize animates before the pass, in the same transaction
    var context: RenderableUpdateContext?
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 50)
        .onUpdate { _, update in
          context = update
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    view.refresh(animated: false)
    let other = ComposeView {
      ColorNode(.blue)
    }
    .onDidRender { _, _ in
      UIView.animate(withDuration: 0.5) {
        view.layoutIfNeeded()
      }
    }
    other.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    UIView.animate(withDuration: 0.5) {
      view.frame.size.width = 300
    }

    // when: the other view renders, which defers the view's layout until after its pass
    other.refresh(animated: false)

    // then: the row is rendered on the next run loop iteration without following the resize, whose animation has begun
    // by then
    expect(context?.newFrame.width) == 200
    expect(context?.newFrame.width).toEventually(beEqual(to: 300))
    expect(context?.updateType) == .boundsChange
    expect(context?.animationTiming) == nil
    view.layer.removeAllAnimations()
  }

  func test_scrollInAnimation_readsNoResize() throws {
    // given: a tall row, reused through a scroll
    var context: RenderableUpdateContext?
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 300)
        .onUpdate { _, update in
          context = update
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    // when: scrolling with a layout in an animation block
    UIView.animate(withDuration: 0.5) {
      view.contentOffset = CGPoint(x: 0, y: 50)
      view.layoutIfNeeded()
    }

    // then: the row updates without an animation
    expect(context?.updateType) == .boundsChange
    expect(context?.animationTiming) == nil
    view.layer.removeAllAnimations()
  }

  func test_animatedLayout_nestedViewFollowsTheParentsResize() throws {
    for nestedBehavior in [ComposeView.AnimationBehavior.default, .disabled] {
      // given: a nested view filling its parent, showing a row
      var context: RenderableUpdateContext?
      var row: CALayer?
      let parent = ComposeView {
        ComposeViewNode {
          ColorNode(.red)
            .frame(width: .flexible, height: 50)
            .onUpdate { renderable, update in
              row = renderable.layer
              context = update
            }
        }
        .onInsert { renderable, _ in
          (renderable.view as? ComposeView)?.animationBehavior = nestedBehavior
        }
      }
      parent.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
      parent.refresh(animated: false)

      // when: resizing the parent with a layout in an animation block
      UIView.animate(withDuration: 0.5) {
        parent.frame.size.width = 300
        parent.layoutIfNeeded()
      }

      // then: the nested row follows the parent's resize, unless the nested view disables animations
      let expectedTiming = nestedBehavior.isDisabled ? nil : AnimationTiming(timing: .timingFunction(0.5, CAMediaTimingFunction(name: .easeInEaseOut)))
      expect(context?.updateType) == .boundsChange
      expect(context?.animationTiming) == expectedTiming
      expect(row?.frame.width) == 300
      row?.removeAllAnimations()
      parent.layer.removeAllAnimations()
    }
  }

  #endif

  func test_animatedRefresh_nestedViewFollowsItsFrameAnimation() throws {
    for nestedBehavior in [ComposeView.AnimationBehavior.default, .disabled] {
      // given: a nested view in a view node with an update animation, showing a row
      let timing = AnimationTiming.linear(duration: 10)
      var width: CGFloat = 100
      var context: RenderableUpdateContext?
      var row: CALayer?
      let nested = ComposeView {
        ColorNode(.red)
          .frame(width: .flexible, height: 50)
          .onUpdate { renderable, update in
            row = renderable.layer
            context = update
          }
      }
      nested.animationBehavior = nestedBehavior
      let parent = ComposeView {
        ViewNode(make: { _ in nested })
          .frame(width: width, height: 100)
          .animation(timing)
      }
      parent.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
      parent.refresh(animated: false)

      // when: an animated refresh widens the nested view
      width = 200
      parent.refresh(animated: true)

      // then: the nested row follows the nested view's frame animation, unless the nested view disables animations
      expect(context?.updateType) == .boundsChange
      expect(context?.animationTiming) == (nestedBehavior.isDisabled ? nil : timing)
      expect(row?.frame.width) == 200
      // and its animations begin at the animation clock's time, as the frame animation that it follows does
      for animation in (row?.animationKeys() ?? []).compactMap({ row?.animation(forKey: $0) }) {
        expect(animation.beginTime) != 0
      }

      // when: a non-animated refresh widens it again
      width = 250
      parent.refresh(animated: false)

      // then: the nested row updates without an animation
      expect(context?.animationTiming) == nil
      expect(row?.frame.width) == 250
      row?.removeAllAnimations()
      (nested.layer as CALayer?)?.removeAllAnimations()
    }
  }

  func test_animatedRefresh_nestedViewLaidOutInItsUpdate_followsItsFrameAnimation() throws {
    // given: a nested view in a view node with an update animation, whose update lays it out, showing a row
    let timing = AnimationTiming.linear(duration: 10)
    var width: CGFloat = 100
    var context: RenderableUpdateContext?
    let nested = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 50)
        .onUpdate { _, update in
          context = update
        }
    }
    let parent = ComposeView {
      ViewNode(make: { _ in nested }, update: { view, _ in
        view.setNeedsLayout()
        view.layoutIfNeeded()
      })
      .frame(width: width, height: 100)
      .animation(timing)
    }
    parent.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
    parent.refresh(animated: false)

    // when: an animated refresh widens the nested view
    width = 200
    parent.refresh(animated: true)

    // then: the layout in the update follows the nested view's frame animation
    expect(context?.updateType) == .boundsChange
    expect(context?.animationTiming) == timing
    expect(context?.newFrame.width) == 200
    (nested.layer as CALayer?)?.removeAllAnimations()
  }

  func test_animatedRefresh_nestedNodeFollowsItsFrameAnimation() throws {
    for isAnimated in [true, false] {
      // given: a nested view node with an update animation, showing a row
      let timing = AnimationTiming.linear(duration: 10)
      var leading: CGFloat = 0
      var width: CGFloat = 100
      var context: RenderableUpdateContext?
      let parent = ComposeView {
        HStack(spacing: 0) {
          Spacer(width: leading)
          ComposeViewNode {
            ColorNode(.red)
              .frame(width: .flexible, height: 50)
              .onUpdate { _, update in
                context = update
              }
          }
          .frame(width: width, height: 100)
          .animation(timing)
          Spacer()
        }
      }
      parent.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
      parent.refresh(animated: false)

      // when: a refresh widens the nested view
      width = 200
      parent.refresh(animated: isAnimated)

      // then: the refresh that the node's update performs follows the frame animation, and a non-animated one doesn't
      expect(context?.updateType, "animated \(isAnimated)") == .refresh
      expect(context?.animationTiming, "animated \(isAnimated)") == (isAnimated ? timing : nil)
      expect(context?.newFrame.width, "animated \(isAnimated)") == 200

      // when: a refresh moves the nested view without resizing it
      leading = 50
      parent.refresh(animated: isAnimated)

      // then: its content has no resize to follow
      expect(context?.updateType, "animated \(isAnimated)") == .refresh
      expect(context?.animationTiming, "animated \(isAnimated)") == nil
      expect(context?.newFrame.width, "animated \(isAnimated)") == 200
    }
  }
}

private extension ComposeView.AnimationBehavior {

  var isDisabled: Bool {
    switch self {
    case .disabled:
      return true
    case .default,
         .dynamic:
      return false
    }
  }
}
