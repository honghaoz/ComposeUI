//
//  CALayer+FrameAnimationTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

class CALayer_FrameAnimationTests: XCTestCase {

  // MARK: - Animate

  func test_animateFrame() throws {
    // given: a layer that counts KVC reads and writes, hosted in a window, filling the window bounds
    let testWindow = TestWindow()

    let layer = KVCCountingLayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = testWindow.layer.bounds

    expect(layer.frame) == CGRect(x: 0, y: 0, width: 500, height: 500)

    // when: animating the frame
    layer.animateFrame(to: CGRect(x: 100, y: 100, width: 50, height: 50), timing: .easeInEaseOut(duration: 1))

    // then: additive position and bounds.size animations are added with the expected values and timing
    expect(layer.animationKeys()) == ["position", "bounds.size"]

    let positionAnimation = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(positionAnimation.fromValue as? CGPoint) == CGPoint(x: 125, y: 125)
    expect(positionAnimation.toValue as? CGPoint) == .zero
    expect(positionAnimation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
    expect(positionAnimation.duration) == 1
    expect(positionAnimation.isAdditive) == true
    expect(positionAnimation.isRemovedOnCompletion) == true
    expect(positionAnimation.fillMode) == .both

    let boundsSizeAnimation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(boundsSizeAnimation.fromValue as? CGSize) == CGSize(width: 450, height: 450)
    expect(boundsSizeAnimation.toValue as? CGSize) == .zero
    expect(boundsSizeAnimation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
    expect(boundsSizeAnimation.duration) == 1
    expect(boundsSizeAnimation.isAdditive) == true
    expect(boundsSizeAnimation.isRemovedOnCompletion) == true
    expect(boundsSizeAnimation.fillMode) == .both

    // then: the model frame is the target frame, and the frame is read and set without KVC
    expect(layer.frame) == CGRect(x: 100, y: 100, width: 50, height: 50)
    expect(layer.kvcReadCount) == 0
    expect(layer.kvcWriteCount) == 0
  }

  func test_animateFrame_viewBacked_setsViewFrameOnce() throws {
    // given: a view in a window that counts its frame sets, and on AppKit its frame-change notifications
    let testWindow = TestWindow()
    let view = FrameTrackingView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
    testWindow.contentView().addSubview(view)
    let layer = view.layer()
    #if canImport(AppKit)
    var notificationCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
      notificationCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }
    #endif
    let frame = CGRect(x: 30, y: 60, width: 140, height: 80)
    let positionOffset = layer.position - layer.position(from: frame)
    view.resetFrameSetCount()

    // when: animating the frame to a new origin and size
    layer.animateFrame(to: frame, timing: .easeInEaseOut(duration: 1))

    // then: the layer animates from its old frame, and the layer and the view land at the new frame
    expect(layer.animationKeys()) == ["position", "bounds.size"]
    let positionAnimation = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(positionAnimation.fromValue as? CGPoint) == positionOffset
    let boundsSizeAnimation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(boundsSizeAnimation.fromValue as? CGSize) == CGSize(width: -40, height: -30)
    expect(layer.frame) == frame
    expect(view.frame) == frame

    // then: an AppKit view's frame is set once, to the new frame, so it posts one frame-change notification. a UIKit
    // view's frame follows its layer without its frame setter
    #if canImport(AppKit)
    expect(view.frameSetCount) == 1
    expect(notificationCount) == 1
    #else
    expect(view.frameSetCount) == 0
    #endif

    // given: the animations removed and the counts reset
    layer.removeAllAnimations()
    view.resetFrameSetCount()
    #if canImport(AppKit)
    notificationCount = 0
    #endif

    // when: setting another frame with a zero-duration timing
    layer.animateFrame(to: CGRect(x: 50, y: 70, width: 60, height: 40), timing: .easeInEaseOut(duration: 0))

    // then: no animation is added, the layer and the view land at the frame, and an AppKit view's frame is set once
    expect(layer.animationKeys()) == nil
    expect(layer.frame) == CGRect(x: 50, y: 70, width: 60, height: 40)
    expect(view.frame) == CGRect(x: 50, y: 70, width: 60, height: 40)
    #if canImport(AppKit)
    expect(view.frameSetCount) == 1
    expect(notificationCount) == 1
    #else
    expect(view.frameSetCount) == 0
    #endif
  }

  func test_animateFrame_animationsKnowTheirPartOfTheFrame() throws {
    for timing in [AnimationTiming.linear(duration: 1), .spring()] {
      // given: frame changes from (20, 20, 100, 60) of a layer anchored at its center, and of one anchored at its origin
      let changes: [(scenario: String, anchorPoint: CGPoint, frame: CGRect, positionPart: FrameAnimationPart)] = [
        ("move", CGPoint(x: 0.5, y: 0.5), CGRect(x: 50, y: 80, width: 100, height: 60), .origin),
        ("resize", CGPoint(x: 0.5, y: 0.5), CGRect(x: 20, y: 20, width: 160, height: 100), .sizeShare),
        ("move and resize", CGPoint(x: 0.5, y: 0.5), CGRect(x: 50, y: 80, width: 160, height: 100), .originAndSizeShare(originPart: SIMD2(-30, -60))),
        ("resize anchored at the origin", .zero, CGRect(x: 20, y: 20, width: 160, height: 100), .origin),
      ]
      for change in changes {
        let scenario = "\(change.scenario), \(timing)"
        let layer = CALayer()
        layer.anchorPoint = change.anchorPoint
        layer.frame = CGRect(x: 20, y: 20, width: 100, height: 60)

        // when: animating the frame
        layer.animateFrame(to: change.frame, timing: timing)

        // then: the animations, as the layer keeps them, know their part: the size, and for the position, the origin's
        // part of its change, the size's share of it, or both with the origin's part
        let positionAnimation = try (layer.animation(forKey: "position") as? any FrameAnimation).unwrap()
        let sizeAnimation = try (layer.animation(forKey: "bounds.size") as? any FrameAnimation).unwrap()
        expect(positionAnimation.part, scenario) == change.positionPart
        expect(sizeAnimation.part, scenario) == .size
      }
    }
  }

  // MARK: - Retarget

  func test_retargetFrame_withoutFrameAnimations_setsTheFrameAndLeavesOtherAnimationsAlone() throws {
    // given: a layer sliding in with an additive position animation of its own, as a slide transition does
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 100, height: 60)
    let slide = CABasicAnimation(keyPath: "position")
    slide.fromValue = CGPoint(x: -200, y: 0)
    slide.toValue = CGPoint.zero
    slide.isAdditive = true
    slide.duration = 10
    layer.add(slide, forKey: "slide")
    let addedSlide = try layer.animation(forKey: "slide").unwrap()

    // when: retargeting the frame
    layer.retargetFrame(to: CGRect(x: 40, y: 50, width: 160, height: 80))

    // then: the frame is set directly, and the slide keeps going as it is
    expect(layer.frame) == CGRect(x: 40, y: 50, width: 160, height: 80)
    expect(layer.animationKeys()) == ["slide"]
    expect(layer.animation(forKey: "slide")) === addedSlide
  }

  func test_retargetFrame_resizeDuringResize_glidesFromTheShownSize() throws {
    // given: a layer growing from 30 to 300 points wide over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
    }
    let shownFrame = try predictedFrame(of: layer, at: 1001)
    expectFrame(shownFrame, CGRect(x: 20, y: 20, width: 97.5, height: 60))

    // when: retargeting the frame back to 30 points wide a second in, when it shows 97.5 points wide
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: the model has the new frame, and the frame shown doesn't jump
    expect(layer.frame) == CGRect(x: 20, y: 20, width: 30, height: 60)
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)

    // then: the size glides from the width shown with an ease-out over the 3 seconds the resize had left, and so does
    // the position's share of it, half of it, so the origin stays
    expect(Set(layer.animationKeys() ?? [])) == ["position", "bounds.size"]
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    expect(sizeGlide.toValue as? CGSize) == .zero
    expect(sizeGlide.isAdditive) == true
    expect(sizeGlide.beginTime) == 1001
    expect(sizeGlide.duration) == 3
    expect(sizeGlide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    let sizeShareGlide = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(sizeShareGlide.fromValue as? CGPoint) == CGPoint(x: 33.75, y: 0)
    expect(sizeShareGlide.isAdditive) == true
    expectSameTiming(sizeShareGlide, as: sizeGlide)
    expect(try predictedFrame(of: layer, at: 1002.5).minX).to(beApproximatelyEqual(to: 20, within: 1e-9))
  }

  func test_retargetFrame_resizeDuringMove_appliesTheSizeAtOnceAndKeepsTheMove() throws {
    // given: a layer moving down by 100 points over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 100, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 100, height: 60), timing: .linear(duration: 4))
    }
    let move = try layer.animation(forKey: "position").unwrap()
    let sizeAnimation = try layer.animation(forKey: "bounds.size").unwrap()

    // when: retargeting the frame to 80 points high at the move's target a second in, when it shows 25 points down
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 120, width: 100, height: 80))
    }

    // then: the height, which isn't animating, takes its new value at once, and the move keeps going as it is
    expect(layer.frame) == CGRect(x: 20, y: 120, width: 100, height: 80)
    expect(layer.animationKeys()) == ["position", "bounds.size"]
    expect(layer.animation(forKey: "position")) === move
    expect(layer.animation(forKey: "bounds.size")) === sizeAnimation
    try expectFrame(predictedFrame(of: layer, at: 1001), CGRect(x: 20, y: 45, width: 100, height: 80))
  }

  func test_retargetFrame_widthChangeDuringHeightResize_appliesAtOnce() throws {
    // given: a layer growing from 60 to 200 points high over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 100, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 100, height: 200), timing: .linear(duration: 4))
    }
    let position = try layer.animation(forKey: "position").unwrap()
    let resize = try layer.animation(forKey: "bounds.size").unwrap()

    // when: retargeting the frame to 150 points wide at the resize's target a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 150, height: 200))
    }

    // then: the width, which isn't animating, takes its new value at once, and the resize keeps going as it is
    expect(layer.frame) == CGRect(x: 20, y: 20, width: 150, height: 200)
    expect(layer.animation(forKey: "position")) === position
    expect(layer.animation(forKey: "bounds.size")) === resize
    try expectFrame(predictedFrame(of: layer, at: 1001), CGRect(x: 20, y: 20, width: 150, height: 95))
  }

  func test_retargetFrame_changedAxesAtRest_takeTheirNewValuesAtOnce() throws {
    // given: a layer growing from 30 to 300 points wide over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
    }

    // when: retargeting the frame a second in to 30 points wide, as well as 80 points high at x 40
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 40, y: 20, width: 30, height: 80))
    }

    // then: the width glides from the 97.5 points shown, while the height and the x origin, which aren't animating, take
    // their new values at once
    expect(layer.frame) == CGRect(x: 40, y: 20, width: 30, height: 80)
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    try expectFrame(predictedFrame(of: layer, at: 1001), CGRect(x: 40, y: 20, width: 97.5, height: 80))
  }

  func test_retargetFrame_moveDuringMoveAndResize_keepsTheResizeAsItIs() throws {
    // given: a layer moving down by 100 points and growing from 30 to 300 points wide over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 300, height: 60), timing: .linear(duration: 4))
    }
    let move = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    let resize = try layer.animation(forKey: "bounds.size").unwrap()
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back up to y 20 at the resize's target a second in, when it shows 25 points down
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60))
    }

    // then: the frame shown doesn't jump
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)

    // then: the resize keeps going as it is, and so does the position's share of it, in a copy of the move's animation
    expect(Set(layer.animationKeys() ?? [])) == ["position", "position-1", "bounds.size"]
    expect(layer.animation(forKey: "bounds.size")) === resize
    let sizeShare = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(sizeShare.fromValue as? CGPoint) == CGPoint(x: -135, y: 0)
    expectSameTiming(sizeShare, as: move)

    // then: the origin glides from where it shows up to y 20 with an ease-out over the 3 seconds the move had left
    let originGlide = try (layer.animation(forKey: "position-1") as? CABasicAnimation).unwrap()
    expect(originGlide.fromValue as? CGPoint) == CGPoint(x: 0, y: 25)
    expect(originGlide.duration) == 3
    expect(originGlide.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    // then: the width keeps the resize's linear motion, with the origin x where it is
    for time in [1002.0, 1003.0] {
      let frame = try predictedFrame(of: layer, at: time)
      expect(frame.width, "\(time)").to(beApproximatelyEqual(to: 300 - 270 * (1 - (time - 1000) / 4), within: 1e-9))
      expect(frame.minX, "\(time)").to(beApproximatelyEqual(to: 20, within: 1e-9))
    }
  }

  func test_retargetFrame_resizeDuringMoveAndResize_keepsTheMoveAsItIs() throws {
    // given: a layer moving down by 100 points and growing from 30 to 300 points wide over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 300, height: 60), timing: .linear(duration: 4))
    }
    let move = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back to 30 points wide at the move's target a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 120, width: 30, height: 60))
    }

    // then: the frame shown doesn't jump
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)

    // then: the move keeps going as it is, in a copy of its animation without the position's share of the resize
    expect(Set(layer.animationKeys() ?? [])) == ["position", "position-1", "bounds.size"]
    let originMove = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(originMove.fromValue as? CGPoint) == CGPoint(x: 0, y: -100)
    expectSameTiming(originMove, as: move)

    // then: the size glides from the 97.5 points shown with an ease-out over the 3 seconds the resize had left, and so
    // does the position's share of it
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    expect(sizeGlide.duration) == 3
    expect(sizeGlide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    let sizeShareGlide = try (layer.animation(forKey: "position-1") as? CABasicAnimation).unwrap()
    expect(sizeShareGlide.fromValue as? CGPoint) == CGPoint(x: 33.75, y: 0)
    expectSameTiming(sizeShareGlide, as: sizeGlide)

    // then: the origin keeps the move's linear motion
    for time in [1002.0, 1003.0] {
      let frame = try predictedFrame(of: layer, at: time)
      expect(frame.minY, "\(time)").to(beApproximatelyEqual(to: 20 + 100 * (time - 1000) / 4, within: 1e-9))
      expect(frame.minX, "\(time)").to(beApproximatelyEqual(to: 20, within: 1e-9))
    }
  }

  func test_retargetFrame_resizeAfterAnEarlierMove_keepsTheMoveAndLandsWithTheResize() throws {
    // given: a layer moving down by 100 points over 4 seconds from 1000, then growing from 30 to 300 points wide over 2
    // seconds from 1000.5
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 30, height: 60), timing: .linear(duration: 4))
    }
    let move = try layer.animation(forKey: "position").unwrap()
    let moveSizeAnimation = try layer.animation(forKey: "bounds.size").unwrap()
    AnimationClock.sharingTime(at: 1000.5) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 300, height: 60), timing: .linear(duration: 2))
    }
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back to 30 points wide at 1001
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 120, width: 30, height: 60))
    }

    // then: the move keeps going as it is, with its size animation, which doesn't move the size, and the resize folds
    // into glides from the frame shown, which land when the resize would have, 1.5 seconds later, instead of with the
    // longer move
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)
    expect(Set(layer.animationKeys() ?? [])) == ["position", "position-1", "bounds.size", "bounds.size-1"]
    expect(layer.animation(forKey: "position")) === move
    expect(layer.animation(forKey: "bounds.size")) === moveSizeAnimation
    let sizeGlide = try (layer.animation(forKey: "bounds.size-1") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    expect(sizeGlide.duration) == 1.5
    let sizeShareGlide = try (layer.animation(forKey: "position-1") as? CABasicAnimation).unwrap()
    expect(sizeShareGlide.fromValue as? CGPoint) == CGPoint(x: 33.75, y: 0)
    expectSameTiming(sizeShareGlide, as: sizeGlide)
  }

  func test_retargetFrame_widthChangeWhileTheHeightAnimatesApart_keepsTheHeightAnimation() throws {
    // given: a layer growing from 30 to 300 points wide over 4 seconds, and from 60 to 200 points high over 8 seconds,
    // both from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 200), timing: .linear(duration: 8))
    }
    let heightResize = try layer.animation(forKey: "bounds.size-1").unwrap()
    let heightShare = try layer.animation(forKey: "position-1").unwrap()
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back to 30 points wide a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 200))
    }

    // then: the frame shown doesn't jump, and the height, which didn't change, keeps its animations as they are
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)
    expect(Set(layer.animationKeys() ?? [])) == ["position", "position-1", "bounds.size", "bounds.size-1"]
    expect(layer.animation(forKey: "bounds.size-1")) === heightResize
    expect(layer.animation(forKey: "position-1")) === heightShare

    // then: the width glides from the 97.5 points shown over the 3 seconds its resize had left, instead of the 7 seconds
    // of the height's
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    expect(sizeGlide.duration) == 3
    let sizeShareGlide = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(sizeShareGlide.fromValue as? CGPoint) == CGPoint(x: 33.75, y: 0)
    expectSameTiming(sizeShareGlide, as: sizeGlide)

    // then: the width lands at 1004, and the height keeps its linear motion, with the origin where it is
    expect(try predictedFrame(of: layer, at: 1004).width).to(beApproximatelyEqual(to: 30, within: 1e-9))
    for time in [1002.0, 1004.0, 1006.0] {
      let frame = try predictedFrame(of: layer, at: time)
      expect(frame.height, "\(time)").to(beApproximatelyEqual(to: 60 + 140 * (time - 1000) / 8, within: 1e-9))
      expect(frame.minX, "\(time)").to(beApproximatelyEqual(to: 20, within: 1e-9))
      expect(frame.minY, "\(time)").to(beApproximatelyEqual(to: 20, within: 1e-9))
    }
  }

  func test_retargetFrame_widthChangeDuringResizeOfBothAxes_keepsTheHeightInCopies() throws {
    // given: a layer growing from 30 to 300 points wide and from 60 to 200 points high over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 200), timing: .linear(duration: 4))
    }
    let positionAnimation = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    let resize = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back to 30 points wide a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 200))
    }

    // then: the frame shown doesn't jump
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)
    expect(Set(layer.animationKeys() ?? [])) == ["position", "position-1", "bounds.size", "bounds.size-1"]

    // then: the height, which didn't change, keeps the resize's motion in copies of its animations, with their timing
    let heightResize = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(heightResize.fromValue as? CGSize) == CGSize(width: 0, height: -140)
    expectSameTiming(heightResize, as: resize)
    let heightShare = try (layer.animation(forKey: "position") as? any FrameAnimation).unwrap()
    expect(heightShare.fromValue as? CGPoint) == CGPoint(x: 0, y: -70)
    expect(heightShare.part) == .sizeShare
    expectSameTiming(heightShare, as: positionAnimation)

    // then: the width glides from the 97.5 points shown over the 3 seconds the resize had left
    let sizeGlide = try (layer.animation(forKey: "bounds.size-1") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    expect(sizeGlide.duration) == 3
    let sizeShareGlide = try (layer.animation(forKey: "position-1") as? CABasicAnimation).unwrap()
    expect(sizeShareGlide.fromValue as? CGPoint) == CGPoint(x: 33.75, y: 0)

    // then: the height keeps the resize's linear motion, with the origin where it is
    for time in [1002.0, 1003.0] {
      let frame = try predictedFrame(of: layer, at: time)
      expect(frame.height, "\(time)").to(beApproximatelyEqual(to: 60 + 140 * (time - 1000) / 4, within: 1e-9))
      expect(frame.minX, "\(time)").to(beApproximatelyEqual(to: 20, within: 1e-9))
      expect(frame.minY, "\(time)").to(beApproximatelyEqual(to: 20, within: 1e-9))
    }
  }

  func test_retargetFrame_axesOfDifferentRemainingTimes_glideApart() throws {
    // given: a layer growing from 30 to 300 points wide over 4 seconds, and from 60 to 200 points high over 8 seconds,
    // both from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 200), timing: .linear(duration: 8))
    }
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back to 30 points wide and 60 points high a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: the frame shown doesn't jump, and each axis glides over the time its resize had left, with the position's
    // share of it: the width from the 97.5 points shown over 3 seconds, and the height from the 77.5 points shown over 7
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)
    expect(Set(layer.animationKeys() ?? [])) == ["position", "position-1", "bounds.size", "bounds.size-1"]
    let widthGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(widthGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    expect(widthGlide.duration) == 3
    let heightGlide = try (layer.animation(forKey: "bounds.size-1") as? CABasicAnimation).unwrap()
    expect(heightGlide.fromValue as? CGSize) == CGSize(width: 0, height: 17.5)
    expect(heightGlide.duration) == 7
    let widthShareGlide = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(widthShareGlide.fromValue as? CGPoint) == CGPoint(x: 33.75, y: 0)
    expectSameTiming(widthShareGlide, as: widthGlide)
    let heightShareGlide = try (layer.animation(forKey: "position-1") as? CABasicAnimation).unwrap()
    expect(heightShareGlide.fromValue as? CGPoint) == CGPoint(x: 0, y: 8.75)
    expectSameTiming(heightShareGlide, as: heightGlide)

    // then: each axis lands when its resize would have, with the origin where it is
    let frameAtWidthLanding = try predictedFrame(of: layer, at: 1004)
    expect(frameAtWidthLanding.width).to(beApproximatelyEqual(to: 30, within: 1e-9))
    expect(frameAtWidthLanding.height) > 60
    expect(frameAtWidthLanding.minX).to(beApproximatelyEqual(to: 20, within: 1e-9))
    expect(frameAtWidthLanding.minY).to(beApproximatelyEqual(to: 20, within: 1e-9))
    try expectFrame(predictedFrame(of: layer, at: 1008), CGRect(x: 20, y: 20, width: 30, height: 60))
  }

  func test_retargetFrame_moveAlongOneAxis_keepsTheMoveAlongTheOther() throws {
    // given: a layer moving right by 100 points over 4 seconds, and down by 100 points over 8 seconds, both from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 120, y: 20, width: 30, height: 60), timing: .linear(duration: 4))
      layer.animateFrame(to: CGRect(x: 120, y: 120, width: 30, height: 60), timing: .linear(duration: 8))
    }
    let downMove = try layer.animation(forKey: "position-1").unwrap()
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back to x 20 a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 120, width: 30, height: 60))
    }

    // then: the frame shown doesn't jump, the move down keeps going as it is, and the x glides from the 45 shown over the
    // 3 seconds its move had left
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)
    expect(layer.animation(forKey: "position-1")) === downMove
    let originGlide = try (layer.animation(forKey: "position") as? any FrameAnimation).unwrap()
    expect(originGlide.part) == .origin
    expect(originGlide.fromValue as? CGPoint) == CGPoint(x: 25, y: 0)
    expect(originGlide.duration) == 3

    // then: the y keeps its linear motion
    for time in [1002.0, 1004.0, 1006.0] {
      let frame = try predictedFrame(of: layer, at: time)
      expect(frame.minY, "\(time)").to(beApproximatelyEqual(to: 20 + 100 * (time - 1000) / 8, within: 1e-9))
    }
    expect(try predictedFrame(of: layer, at: 1004).minX).to(beApproximatelyEqual(to: 20, within: 1e-9))
  }

  func test_retargetFrame_toTheFrameShown_addsNoGlide() throws {
    for step in 1 ... 9 {
      // given: a layer moving and growing between frames of uneven values over 0.35 seconds with an ease-in-ease-out curve
      // from 1000
      let time = 1000 + 0.35 * TimeInterval(step) / 10
      let layer = CALayer()
      layer.frame = CGRect(x: 13.3, y: 7.7, width: 31.7, height: 61.9)
      AnimationClock.sharingTime(at: 1000) {
        layer.animateFrame(to: CGRect(x: 41.1, y: 19.3, width: 297.3, height: 143.1), timing: .easeInEaseOut(duration: 0.35))
      }
      let shownFrame = try predictedFrame(of: layer, at: time)

      // when: retargeting the frame to the frame shown
      AnimationClock.sharingTime(at: time) {
        layer.retargetFrame(to: shownFrame)
      }

      // then: the glides are sums that cancel out to rounding errors, so none is added, as a later retarget would see no
      // motion in them, and the frame shows the new frame at once
      expect(layer.animationKeys(), "step \(step)") == nil
      expectFrame(layer.frame, shownFrame)
    }
  }

  func test_retargetFrame_springInFlight_keepsTheSpringAndGlidesTheJump() throws {
    // given: a layer springing from 30 to 300 points wide from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .spring(dampingRatio: 0.8, response: 0.5))
    }
    let positionSpring = try (layer.animation(forKey: "position") as? CASpringAnimation).unwrap()
    let sizeSpring = try (layer.animation(forKey: "bounds.size") as? CASpringAnimation).unwrap()
    let shownFrame = try predictedFrame(of: layer, at: 1000.1)

    // when: retargeting the frame to 200 points wide 0.1 seconds in
    AnimationClock.sharingTime(at: 1000.1) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 200, height: 60))
    }

    // then: the springs keep going as they are, so their momentum carries on, and the frame shown doesn't jump
    expect(layer.animation(forKey: "position")) === positionSpring
    expect(layer.animation(forKey: "bounds.size")) === sizeSpring
    try expectFrame(predictedFrame(of: layer, at: 1000.1), shownFrame, within: 1e-6)

    // then: glides stacked on the springs cover the jump the model change would show, 100 points, over the springs'
    // remaining time
    let sizeGlide = try (layer.animation(forKey: "bounds.size-1") as? CABasicAnimation).unwrap()
    expect(sizeGlide is CASpringAnimation) == false
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 100, height: 0)
    expect(sizeGlide.duration).to(beApproximatelyEqual(to: sizeSpring.duration - 0.1, within: 1e-9))
    expect(sizeGlide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    let sizeShareGlide = try (layer.animation(forKey: "position-1") as? CABasicAnimation).unwrap()
    expect(sizeShareGlide.fromValue as? CGPoint) == CGPoint(x: 50, y: 0)
  }

  func test_retargetFrame_springThatNeverSettles_foldsWholeAndGlidesOverTheDefaultDuration() throws {
    // given: a layer springing from 30 to 300 points wide and from 60 to 100 points high without damping from 1000, so
    // it bounces forever
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 100), timing: .spring(dampingRatio: 0, response: 0.5))
    }
    let shownFrame = try predictedFrame(of: layer, at: 1000.3)

    // when: retargeting the frame to 200 points wide 0.3 seconds in
    AnimationClock.sharingTime(at: 1000.3) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 200, height: 100))
    }

    // then: the spring folds whole, its height too, as a path that follows the frame can't keep it next to a glide, and
    // the frame shown doesn't jump
    expect(Set(layer.animationKeys() ?? [])) == ["position", "bounds.size"]
    expect(layer.animation(forKey: "bounds.size") is CASpringAnimation) == false
    try expectFrame(predictedFrame(of: layer, at: 1000.3), shownFrame, within: 1e-6)

    // then: the spring has no landing to glide to, so the frame glides over the default duration instead of forever, and
    // lands on the new frame
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.duration) == Animations.defaultAnimationDuration
    try expectFrame(predictedFrame(of: layer, at: 1000.3 + Animations.defaultAnimationDuration), CGRect(x: 20, y: 20, width: 200, height: 100))
  }

  func test_retargetFrame_repeatedly_keepsOneGlidePerPart() throws {
    // given: a layer moving down by 100 points and growing from 30 to 300 points wide over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 300, height: 60), timing: .linear(duration: 4))
    }

    // when: retargeting the frame 60 times a frame apart, back and forth between two widths and two origins, as
    // non-animated updates every frame would
    for step in 1 ... 60 {
      let time = 1001 + TimeInterval(step) / 60
      let shownFrame = try predictedFrame(of: layer, at: time)
      let isEven = step.isMultiple(of: 2)
      AnimationClock.sharingTime(at: time) {
        layer.retargetFrame(to: CGRect(x: 20, y: isEven ? 60 : 80, width: isEven ? 100 : 150, height: 60))
      }

      // then: the frame shown doesn't jump, and each glide folds into the next, so one glide per part is all there is
      try expectFrame(predictedFrame(of: layer, at: time), shownFrame, within: 1e-6)
      expect(Set(layer.animationKeys() ?? []), "\(step)") == ["position", "bounds.size"]
    }
  }

  func test_retargetFrame_moveAndResizeDuringMoveAndResize_glidesThePositionInOneAnimation() throws {
    // given: a layer moving down by 100 points and growing from 30 to 300 points wide over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 300, height: 60), timing: .linear(duration: 4))
    }
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back to the top and to 30 points wide a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: the frame shown doesn't jump, and as both parts glide over the 3 seconds their animations had left, one
    // animation glides the position, with the origin's part, 25 points, and the size's share, half of the 67.5 points
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)
    expect(Set(layer.animationKeys() ?? [])) == ["position", "bounds.size"]
    let positionGlide = try (layer.animation(forKey: "position") as? any FrameAnimation).unwrap()
    expect(positionGlide.part) == .originAndSizeShare(originPart: SIMD2(0, 25))
    expect(positionGlide.fromValue as? CGPoint) == CGPoint(x: 33.75, y: 25)
    expect(positionGlide.duration) == 3
    expect(positionGlide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    expectSameTiming(positionGlide, as: sizeGlide)
  }

  func test_retargetFrame_moveAndResizeOfDifferentDurations_glideApart() throws {
    // given: a layer moving down by 100 points over 4 seconds from 1000, then growing from 30 to 300 points wide over 2
    // seconds from 1000.5
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 30, height: 60), timing: .linear(duration: 4))
    }
    let moveSizeAnimation = try layer.animation(forKey: "bounds.size").unwrap()
    AnimationClock.sharingTime(at: 1000.5) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 300, height: 60), timing: .linear(duration: 2))
    }
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame to y 60 and 100 points wide at 1001
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 60, width: 100, height: 60))
    }

    // then: the frame shown doesn't jump, and each part glides apart, landing when its animations would have: the origin
    // over the 3 seconds the move had left, and the size, with its share of the position, over the resize's 1.5 seconds.
    // the move's size animation, which doesn't move the size, is left alone
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)
    expect(Set(layer.animationKeys() ?? [])) == ["position", "position-1", "bounds.size", "bounds.size-1"]
    let originGlide = try (layer.animation(forKey: "position") as? any FrameAnimation).unwrap()
    expect(originGlide.part) == .origin
    expect(originGlide.fromValue as? CGPoint) == CGPoint(x: 0, y: -15)
    expect(originGlide.duration) == 3
    let sizeShareGlide = try (layer.animation(forKey: "position-1") as? any FrameAnimation).unwrap()
    expect(sizeShareGlide.part) == .sizeShare
    expect(sizeShareGlide.duration) == 1.5
    expect(layer.animation(forKey: "bounds.size")) === moveSizeAnimation
    let sizeGlide = try (layer.animation(forKey: "bounds.size-1") as? CABasicAnimation).unwrap()
    expect(sizeGlide.duration) == 1.5
  }

  func test_retargetFrame_scheduledFrameAnimation_isFoldedFromTheFrameItHolds() throws {
    // given: a layer set to grow from 30 to 300 points wide over 4 seconds after a 2 second delay from 1000, which holds
    // its 30 points until it begins
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4, delay: 2))
    }

    // when: retargeting the frame to 200 points wide at 1001
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 200, height: 60))
    }

    // then: the size glides from the 30 points held to 200 over the 5 seconds until the resize would have landed
    expect(Set(layer.animationKeys() ?? [])) == ["position", "bounds.size"]
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: -170, height: 0)
    expect(sizeGlide.beginTime) == 1001
    expect(sizeGlide.duration) == 5
  }

  func test_retargetFrame_endedFrameAnimations_areLeftAlone() throws {
    // given: a layer whose move of a second from 990 has ended while its animations are still on the layer
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 990) {
      layer.animateFrame(to: CGRect(x: 20, y: 120, width: 30, height: 60), timing: .linear(duration: 1))
    }
    let endedMove = try layer.animation(forKey: "position").unwrap()

    // when: retargeting the frame at 1001
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: nothing is in motion, so the frame is set directly, and the ended animations are left for Core Animation to
    // remove
    expect(layer.frame) == CGRect(x: 20, y: 20, width: 30, height: 60)
    expect(layer.animationKeys()) == ["position", "bounds.size"]
    expect(layer.animation(forKey: "position")) === endedMove

    // when: growing to 300 points wide over 4 seconds from 1001, and retargeting the frame back to 30 points wide at 1002
    AnimationClock.sharingTime(at: 1001) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
    }
    AnimationClock.sharingTime(at: 1002) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: the resize folds into glides, and the ended move is still left alone
    expect(layer.animation(forKey: "position")) === endedMove
    let sizeGlide = try (layer.animation(forKey: "bounds.size-1") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
  }

  func test_retargetFrame_glide_leavesOtherAnimationsOfTheFrameAlone() throws {
    // given: a layer sliding in with an additive position animation of its own over 10 seconds from 1000, as a slide
    // transition does, while it grows from 30 to 300 points wide over 4 seconds from 1000
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    let slide = CABasicAnimation(keyPath: "position")
    slide.fromValue = CGPoint(x: -200, y: 0)
    slide.toValue = CGPoint.zero
    slide.isAdditive = true
    slide.duration = 10
    slide.beginTime = 1000
    layer.add(slide, forKey: "slide")
    let addedSlide = try layer.animation(forKey: "slide").unwrap()
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
    }
    let shownFrame = try predictedFrame(of: layer, at: 1001)

    // when: retargeting the frame back to 30 points wide a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: the resize folds into glides, and the slide keeps going as it is, with the frame shown unchanged
    expect(layer.animation(forKey: "slide")) === addedSlide
    expect(Set(layer.animationKeys() ?? [])) == ["slide", "position", "bounds.size"]
    try expectFrame(predictedFrame(of: layer, at: 1001), shownFrame)
  }

  func test_retargetFrame_anchorPointAtTheOrigin_glidesTheSizeAlone() throws {
    // given: a layer anchored at its origin, so its position doesn't move with its size, growing from 30 to 300 points
    // wide over 4 seconds from 1000
    let layer = CALayer()
    layer.anchorPoint = .zero
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
    }
    let positionAnimation = try layer.animation(forKey: "position").unwrap()

    // when: retargeting the frame back to 30 points wide a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: the size glides alone, without a share of the position, and the position's animation, which doesn't move
    // it, is left alone
    expect(Set(layer.animationKeys() ?? [])) == ["position", "bounds.size"]
    expect(layer.animation(forKey: "position")) === positionAnimation
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
    try expectFrame(predictedFrame(of: layer, at: 1001), CGRect(x: 20, y: 20, width: 97.5, height: 60))
  }

  func test_retargetFrame_frameAnimationWithAnUnevaluableTiming_assertsAndIsKept() throws {
    // given: a layer growing from 30 to 300 points wide over 4 seconds from 1000, with a frame animation of its size that
    // repeats, whose value at a time isn't computed
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
    }
    let repeating = FrameBasicAnimation(keyPath: "bounds.size")
    repeating.part = .size
    repeating.fromValue = CGSize(width: 10, height: 0)
    repeating.toValue = CGSize.zero
    repeating.isAdditive = true
    repeating.duration = 1
    repeating.repeatCount = 3
    repeating.beginTime = 1000.5
    layer.add(repeating, forKey: "repeating")
    let addedRepeating = try layer.animation(forKey: "repeating").unwrap()

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: retargeting the frame back to 30 points wide a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: it asserts, and keeps the repeating animation going while the resize folds into glides
    expect(assertionMessages.count) == 1
    expect(assertionMessages.first?.hasPrefix("frame animation \"repeating\" has a timing that can't be evaluated")) == true
    expect(layer.animation(forKey: "repeating")) === addedRepeating
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
  }

  func test_retargetFrame_frameAnimationWithoutAnOffsetOfItsPart_assertsAndIsKept() throws {
    // given: a layer growing from 30 to 300 points wide over 4 seconds from 1000, with frame animations whose from values
    // aren't offsets of their parts
    let layer = CALayer()
    layer.frame = CGRect(x: 20, y: 20, width: 30, height: 60)
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 20, y: 20, width: 300, height: 60), timing: .linear(duration: 4))
    }
    let malformedAnimations: [(key: String, keyPath: String, fromValue: Any?, part: FrameAnimationPart)] = [
      ("no-value", "position", nil, .origin),
      ("not-a-size", "bounds.size", Float(10), .size),
    ]
    for malformed in malformedAnimations {
      let animation = FrameBasicAnimation(keyPath: malformed.keyPath)
      animation.part = malformed.part
      animation.fromValue = malformed.fromValue
      animation.duration = 10
      animation.beginTime = 1000
      animation.isAdditive = true
      layer.add(animation, forKey: malformed.key)
    }

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: retargeting the frame back to 30 points wide a second in
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: CGRect(x: 20, y: 20, width: 30, height: 60))
    }

    // then: it asserts for each, and keeps them while the resize folds into glides
    expect(assertionMessages.count) == malformedAnimations.count
    for (message, malformed) in zip(assertionMessages, malformedAnimations) {
      expect(message.hasPrefix("frame animation \"\(malformed.key)\" doesn't animate its part from a value"), malformed.key) == true
      expect(layer.animation(forKey: malformed.key), malformed.key) != nil
    }
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: 67.5, height: 0)
  }

  func test_retargetFrame_viewBacked_setsViewFrameOnce() throws {
    // given: a view in a window that counts its frame sets, and on AppKit its frame-change notifications, growing from
    // 100 to 300 points wide over 4 seconds from 1000
    let testWindow = TestWindow()
    let view = FrameTrackingView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
    testWindow.contentView().addSubview(view)
    let layer = view.layer()
    AnimationClock.sharingTime(at: 1000) {
      layer.animateFrame(to: CGRect(x: 10, y: 20, width: 300, height: 50), timing: .linear(duration: 4))
    }
    #if canImport(AppKit)
    var notificationCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
      notificationCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }
    #endif
    view.resetFrameSetCount()

    // when: retargeting the frame to a new origin and 200 points wide a second in
    let frame = CGRect(x: 30, y: 40, width: 200, height: 50)
    AnimationClock.sharingTime(at: 1001) {
      layer.retargetFrame(to: frame)
    }

    // then: the size glides from the 150 points shown, and the layer and the view are at the new frame
    let sizeGlide = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(sizeGlide.fromValue as? CGSize) == CGSize(width: -50, height: 0)
    expect(layer.frame) == frame
    expect(view.frame) == frame

    // then: an AppKit view's frame is set once, to the new frame, so it posts one frame-change notification. a UIKit
    // view's frame follows its layer without its frame setter
    #if canImport(AppKit)
    expect(view.frameSetCount) == 1
    expect(notificationCount) == 1
    #else
    expect(view.frameSetCount) == 0
    #endif

    // given: the animations removed and the counts reset
    layer.removeAllAnimations()
    view.resetFrameSetCount()
    #if canImport(AppKit)
    notificationCount = 0
    #endif

    // when: retargeting the frame without animations in flight
    layer.retargetFrame(to: CGRect(x: 50, y: 70, width: 60, height: 40))

    // then: the frame is set directly, again with one frame set on AppKit
    expect(view.frame) == CGRect(x: 50, y: 70, width: 60, height: 40)
    #if canImport(AppKit)
    expect(view.frameSetCount) == 1
    expect(notificationCount) == 1
    #else
    expect(view.frameSetCount) == 0
    #endif
  }

  // MARK: - Helpers

  /// The frame a layer shows at a time according to its animations of the position and the size, see
  /// `predictedValue(forKeyPath:at:scalar:)`.
  private func predictedFrame(of layer: CALayer, at time: TimeInterval) throws -> CGRect {
    let x = try layer.predictedValue(forKeyPath: "position", at: time) { try ($0 as? CGPoint).unwrap().x }
    let y = try layer.predictedValue(forKeyPath: "position", at: time) { try ($0 as? CGPoint).unwrap().y }
    let width = try layer.predictedValue(forKeyPath: "bounds.size", at: time) { try ($0 as? CGSize).unwrap().width }
    let height = try layer.predictedValue(forKeyPath: "bounds.size", at: time) { try ($0 as? CGSize).unwrap().height }
    let anchorPoint = layer.anchorPoint
    return CGRect(x: x - anchorPoint.x * width, y: y - anchorPoint.y * height, width: width, height: height)
  }

  /// Expects a frame to be within a tolerance of another, edge by edge.
  private func expectFrame(_ frame: CGRect, _ expected: CGRect, within tolerance: CGFloat = 1e-9, file: StaticString = #filePath, line: UInt = #line) {
    let description = "\(frame) is not \(expected)"
    expect(frame.minX, description, file: file, line: line).to(beApproximatelyEqual(to: expected.minX, within: tolerance))
    expect(frame.minY, description, file: file, line: line).to(beApproximatelyEqual(to: expected.minY, within: tolerance))
    expect(frame.width, description, file: file, line: line).to(beApproximatelyEqual(to: expected.width, within: tolerance))
    expect(frame.height, description, file: file, line: line).to(beApproximatelyEqual(to: expected.height, within: tolerance))
  }

  /// Expects an animation to have the timing of another.
  private func expectSameTiming(_ animation: CABasicAnimation, as other: CABasicAnimation, file: StaticString = #filePath, line: UInt = #line) {
    expect(type(of: animation) == type(of: other), file: file, line: line) == true
    expect(animation.beginTime, file: file, line: line) == other.beginTime
    expect(animation.duration, file: file, line: line) == other.duration
    expect(animation.speed, file: file, line: line) == other.speed
    expect(animation.timingFunction, file: file, line: line) == other.timingFunction
  }
}
