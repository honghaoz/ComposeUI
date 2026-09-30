//
//  CALayer+ShownValueTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/26.
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

class CALayer_ShownValueTests: XCTestCase {

  private let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
  private let blue = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)

  // MARK: - Model Value

  func test_shownValue_nothingAnimating_isTheModelValue() throws {
    // given: a layer with model values and nothing animating
    let layer = CALayer()
    layer.opacity = 0.3
    layer.cornerRadius = 5
    layer.backgroundColor = red
    layer.shadowPath = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil)
    layer.zPosition = 2

    // then: each key path shows its model value, and a layer without a background color shows none
    expect(layer.shownValue(forKeyPath: "opacity") as? Float) == 0.3
    expect(layer.shownValue(forKeyPath: "cornerRadius") as? CGFloat) == 5
    expect(layer.shownValue(forKeyPath: "backgroundColor") as AnyObject) === red
    expect(layer.shownValue(forKeyPath: "shadowPath") as AnyObject) === layer.shadowPath
    expect(layer.shownValue(forKeyPath: "zPosition") as? CGFloat) == 2
    expect(CALayer().shownValue(forKeyPath: "backgroundColor")) == nil
  }

  func test_shownValue_otherKeyPathsAnimating_isTheModelValue() {
    // given: a red layer whose position animates, directly and in a group
    let layer = TimeConversionCountingLayer()
    layer.backgroundColor = red
    layer.add(animation(keyPath: "position", from: CGPoint(x: 0, y: 0), to: CGPoint(x: 10, y: 10)), forKey: "position")
    layer.add(group(of: [CABasicAnimation(keyPath: "position")]), forKey: "group-move")

    // when: reading the background color
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      layer.shownValue(forKeyPath: "backgroundColor")
    }

    // then: it's the model color, read without converting the clock's time to the layer's
    expect(shown as AnyObject) === red
    expect(layer.timeConversionCount) == 0
  }

  func test_shownValue_readsTheClocksTime() throws {
    // given: a layer whose border width animates from 0 to 20 over two seconds, from 1000
    let layer = TimeConversionCountingLayer()
    layer.add(animation(keyPath: "borderWidth", from: 0.0, to: 20.0), forKey: "borderWidth")

    // when: reading the border width with the clock at 1000.5
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      layer.shownValue(forKeyPath: "borderWidth")
    }

    // then: it's a quarter of the way, with the clock's time converted to the layer's once
    expect(shown as? Double) == 5
    expect(layer.timeConversionCount) == 1
  }

  // MARK: - Clamped Numbers

  func test_shownValue_opacity_isTheModelsType() throws {
    for keyPath in ["opacity", "shadowOpacity"] {
      // given: a layer whose opacity animates from 0.2 to 1 over two seconds, from 1000
      let layer = CALayer()
      layer.add(animation(keyPath: keyPath, from: 0.2, to: 1.0), forKey: keyPath)

      // when: reading the opacity at 1000.5
      let shown = AnimationClock.sharingTime(at: 1000.5) {
        layer.shownValue(forKeyPath: keyPath)
      }

      // then: it's a quarter of the way, as the property's Float
      expect(try unwrap(shown as? Float, keyPath)).to(beApproximatelyEqual(to: 0.4, within: 1e-6))
    }
  }

  func test_shownValue_opacity_clampsAfterEachAnimation() throws {
    // given: a layer at 0.5 with two additive opacity animations, from 0.8 and from -0.3 to 0, over two seconds
    let layer = CALayer()
    layer.opacity = 0.5
    layer.add(animation(keyPath: "opacity", from: 0.8, to: 0.0, isAdditive: true), forKey: "opacity")
    layer.add(animation(keyPath: "opacity", from: -0.3, to: 0.0, isAdditive: true), forKey: "opacity-1")

    // when: reading the opacity a quarter of the way
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      layer.shownValue(forKeyPath: "opacity")
    }

    // then: the first animation takes it to 1.1, clamped to 1 as the render server does, and the second to 0.775,
    // instead of the unclamped sum 0.875
    expect(try unwrap(shown as? Float)).to(beApproximatelyEqual(to: 0.775, within: 1e-6))
  }

  func test_shownValue_cornerRadius_clampsAtZeroAfterEachAnimation() throws {
    // given: a layer with a corner radius of 2 and two additive animations, from -4 and from 2 to 0, beginning at 1000.5
    let layer = CALayer()
    layer.cornerRadius = 2
    layer.add(animation(keyPath: "cornerRadius", from: -4.0, to: 0.0, beginTime: 1000.5, isAdditive: true), forKey: "cornerRadius")
    layer.add(animation(keyPath: "cornerRadius", from: 2.0, to: 0.0, beginTime: 1000.5, isAdditive: true), forKey: "cornerRadius-1")

    // when: reading the corner radius as they begin
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      layer.shownValue(forKeyPath: "cornerRadius")
    }

    // then: the first animation takes it to -2, clamped to 0 as the render server does, and the second to 2, as the
    // property's CGFloat, instead of the unclamped sum 0
    expect(shown as? CGFloat) == 2
  }

  func test_shownValue_clampedNumber_animationNotShowing_isTheModelValue() throws {
    // given: a layer at 0.3 whose opacity animation to 1 begins at 1001, without a backwards fill
    let layer = CALayer()
    layer.opacity = 0.3
    let opacityAnimation = animation(keyPath: "opacity", from: 0.0, to: 1.0, beginTime: 1001)
    opacityAnimation.fillMode = .removed
    layer.add(opacityAnimation, forKey: "opacity")

    // when: reading the opacity at 1000.5
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      layer.shownValue(forKeyPath: "opacity")
    }

    // then: the animation doesn't show yet, so it's the model opacity
    expect(shown as? Float) == 0.3
  }

  // MARK: - Values

  func test_shownValue_color_interpolates() throws {
    // given: a layer whose background color animates from red to blue over two seconds, from 1000
    let layer = CALayer()
    layer.add(animation(keyPath: "backgroundColor", from: red, to: blue), forKey: "backgroundColor")

    // when: reading the background color a quarter of the way
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      layer.shownValue(forKeyPath: "backgroundColor")
    }

    // then: it's a quarter of the way, see `AnimationInterpolation`
    try expectExtendedSRGBComponents(of: colorValue(shown), toBe: [0.75, 0, 0.25, 1])
  }

  func test_shownValue_additiveAndNonAdditiveAnimations_composeInOrder() throws {
    // given: a layer at (100, 100) whose position animates additively from (-40, 20) to (0, 0), and a layer whose
    // shadow radius animates additively from 4 to 0 under a non-additive animation from 2 to 10, over two seconds
    let pointLayer = CALayer()
    pointLayer.position = CGPoint(x: 100, y: 100)
    pointLayer.add(animation(keyPath: "position", from: CGPoint(x: -40, y: 20), to: CGPoint.zero, isAdditive: true), forKey: "position")
    let radiusLayer = CALayer()
    radiusLayer.shadowRadius = 10
    radiusLayer.add(animation(keyPath: "shadowRadius", from: 4.0, to: 0.0, isAdditive: true), forKey: "shadowRadius")
    radiusLayer.add(animation(keyPath: "shadowRadius", from: 2.0, to: 10.0), forKey: "shadowRadius-1")

    // when: reading them a quarter of the way
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      (pointLayer.shownValue(forKeyPath: "position"), radiusLayer.shownValue(forKeyPath: "shadowRadius"))
    }

    // then: the additive animation adds to the model value, and the non-additive one replaces what's below it
    expect(shown.0 as? CGPoint) == CGPoint(x: 70, y: 115)
    expect(shown.1 as? Double) == 4
  }

  func test_shownValue_animationBeginningNow_isItsFromValue() throws {
    // given: a layer whose background color animation from red to blue begins at 1000.5
    let layer = CALayer()
    layer.add(animation(keyPath: "backgroundColor", from: red, to: blue, beginTime: 1000.5), forKey: "backgroundColor")

    // when: reading the background color at 1000.5
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      layer.shownValue(forKeyPath: "backgroundColor")
    }

    // then: it's the from color itself
    expect(shown as AnyObject) === red
  }

  func test_shownValue_endedAnimation_showsItsToValueOnlyWhenKeptWithAForwardsFill() throws {
    let cases: [(name: String, isRemovedOnCompletion: Bool, fillMode: CAMediaTimingFillMode, shown: CGColor)] = [
      ("removed on completion", true, .both, red),
      ("kept with a forwards fill", false, .forwards, blue),
      ("kept with a backwards fill", false, .backwards, red),
    ]
    for testCase in cases {
      // given: a red layer whose background color animation to blue ended at 999
      let layer = CALayer()
      layer.backgroundColor = red
      let colorAnimation = animation(keyPath: "backgroundColor", from: CGColor(gray: 0, alpha: 1), to: blue, beginTime: 997)
      colorAnimation.isRemovedOnCompletion = testCase.isRemovedOnCompletion
      colorAnimation.fillMode = testCase.fillMode
      layer.add(colorAnimation, forKey: "backgroundColor")

      // when: reading the background color at 1000.5
      let shown = AnimationClock.sharingTime(at: 1000.5) {
        layer.shownValue(forKeyPath: "backgroundColor")
      }

      // then: a kept animation with a forwards fill shows its to color itself, and the others the model color
      expect(shown as AnyObject, testCase.name) === testCase.shown
    }
  }

  func test_shownValue_scheduledAnimation_showsItsFromValueOnlyWithABackwardsFill() throws {
    let cases: [(fillMode: CAMediaTimingFillMode, shown: CGColor)] = [
      (.removed, red),
      (.backwards, CGColor(gray: 0, alpha: 1)),
    ]
    for testCase in cases {
      // given: a red layer whose background color animation to blue begins at 1001
      let layer = CALayer()
      layer.backgroundColor = red
      let colorAnimation = animation(keyPath: "backgroundColor", from: testCase.shown, to: blue, beginTime: 1001)
      colorAnimation.fillMode = testCase.fillMode
      layer.add(colorAnimation, forKey: "backgroundColor")

      // when: reading the background color at 1000.5
      let shown = AnimationClock.sharingTime(at: 1000.5) {
        layer.shownValue(forKeyPath: "backgroundColor")
      }

      // then: with a backwards fill it's the from color, and without one the model color
      expect(shown as AnyObject, "\(testCase.fillMode)") === testCase.shown
    }
  }

  func test_shownValue_animationNotShowing_isSkippedWhateverItsValuesOrTiming() throws {
    for keyPath in ["borderWidth", "opacity"] {
      let laterToOnlyAnimation = animation(keyPath: keyPath, from: nil, to: 1.0, beginTime: 1001)
      laterToOnlyAnimation.fillMode = .removed
      let endedToOnlyAnimation = animation(keyPath: keyPath, from: nil, to: 1.0, beginTime: 997)
      let laterKeyframeAnimation = CAKeyframeAnimation(keyPath: keyPath)
      laterKeyframeAnimation.values = [0.0, 1.0]
      laterKeyframeAnimation.beginTime = 1001
      laterKeyframeAnimation.duration = 2
      func laterAnimation(_ configure: (CABasicAnimation) -> Void) -> CABasicAnimation {
        let animation = animation(keyPath: keyPath, from: 0.0, to: 1.0, beginTime: 1001)
        animation.fillMode = .removed
        configure(animation)
        return animation
      }

      let cases: [(name: String, animation: CAAnimation)] = [
        ("a to-only animation that begins later", laterToOnlyAnimation),
        ("a to-only animation that has ended", endedToOnlyAnimation),
        ("a keyframe animation that begins later", laterKeyframeAnimation),
        ("a repeating animation that begins later", laterAnimation { $0.repeatCount = 2 }),
        ("an animation repeating for a duration that begins later", laterAnimation { $0.repeatDuration = 4 }),
        ("an autoreversing animation that begins later", laterAnimation { $0.autoreverses = true }),
        ("an animation with a time offset that begins later", laterAnimation { $0.timeOffset = 0.5 }),
      ]
      for testCase in cases {
        // given: a layer at 0.25, raised by an additive animation of 0.5 over two seconds from 1000, with an animation
        // that can't be evaluated and doesn't show at 1000.5, as it begins later without a backwards fill or has ended
        let layer = CALayer()
        layer.borderWidth = 0.25
        layer.opacity = 0.25
        layer.add(animation(keyPath: keyPath, from: 0.0, to: 0.5, isAdditive: true), forKey: "raise")
        layer.add(testCase.animation, forKey: "unevaluable")

        // when: reading the key path at 1000.5
        let shown = AnimationClock.sharingTime(at: 1000.5) {
          layer.shownValue(forKeyPath: keyPath)
        }

        // then: the animation that doesn't show is skipped, so the model value is raised by a quarter of 0.5
        let description = "\(testCase.name) of \(keyPath)"
        expect(try unwrap((shown as? NSNumber)?.doubleValue, description), description) == 0.375
      }
    }
  }

  // MARK: - Typed Values

  func test_shownColorPathAndOpacity() throws {
    // given: a layer whose background color, shadow path and shadow opacity animate over two seconds, from 1000
    let layer = CALayer()
    let square = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    layer.add(animation(keyPath: "backgroundColor", from: red, to: blue), forKey: "backgroundColor")
    layer.add(animation(keyPath: "shadowPath", from: square, to: CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 100), transform: nil)), forKey: "shadowPath")
    layer.add(animation(keyPath: "shadowOpacity", from: 0.0, to: 1.0), forKey: "shadowOpacity")

    // when: reading them a quarter of the way
    let shown = AnimationClock.sharingTime(at: 1000.5) {
      (color: layer.shownColor(forKeyPath: "backgroundColor"), path: layer.shownPath(forKeyPath: "shadowPath"), opacity: layer.shownOpacity(forKeyPath: "shadowOpacity"))
    }

    // then: they're the values of their types a quarter of the way
    try expectExtendedSRGBComponents(of: unwrap(shown.color), toBe: [0.75, 0, 0.25, 1])
    expect(try PathPoints(unwrap(shown.path))) == PathPoints(CGPath(rect: CGRect(x: 0, y: 0, width: 125, height: 100), transform: nil))
    expect(shown.opacity) == 0.25

    // then: a key path without a value, or with a value of another type, has none of the type
    expect(CALayer().shownColor(forKeyPath: "backgroundColor")) == nil
    expect(layer.shownColor(forKeyPath: "opacity")) == nil
    expect(layer.shownPath(forKeyPath: "backgroundColor")) == nil
    expect(layer.shownOpacity(forKeyPath: "backgroundColor")) == nil
  }

  // MARK: - Unevaluable Animations

  func test_shownValue_unevaluableAnimation_withoutPresentation_isNil() throws {
    var callbacks = CGPatternCallbacks(version: 0, drawPattern: { _, _ in }, releaseInfo: nil)
    let pattern = try CGPattern(info: nil, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), matrix: .identity, xStep: 1, yStep: 1, tiling: .noDistortion, isColored: true, callbacks: &callbacks).unwrap()
    var alpha: CGFloat = 1
    let patternColor = try CGColor(patternSpace: CGColorSpace(patternBaseSpace: nil).unwrap(), pattern: pattern, components: &alpha).unwrap()
    let square = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let ellipse = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let keyframeAnimation = CAKeyframeAnimation(keyPath: "backgroundColor")
    keyframeAnimation.values = [red, blue]
    keyframeAnimation.beginTime = 1000
    keyframeAnimation.duration = 2
    let byAnimation = animation(keyPath: "backgroundColor", from: red, to: blue)
    byAnimation.byValue = blue
    let repeatingAnimation = animation(keyPath: "backgroundColor", from: red, to: blue)
    repeatingAnimation.repeatCount = 2
    let laterRepeatingAnimation = animation(keyPath: "backgroundColor", from: red, to: blue, beginTime: 1001)
    laterRepeatingAnimation.repeatCount = 2
    let opacityKeyframeAnimation = CAKeyframeAnimation(keyPath: "opacity")
    opacityKeyframeAnimation.values = [0, 1]
    opacityKeyframeAnimation.beginTime = 1000
    opacityKeyframeAnimation.duration = 2
    let opacityByAnimation = animation(keyPath: "opacity", from: 0.0, to: 1.0)
    opacityByAnimation.byValue = 1.0
    let repeatingOpacityAnimation = animation(keyPath: "opacity", from: 0.0, to: 1.0)
    repeatingOpacityAnimation.repeatCount = 2
    let rotation = animation(keyPath: "transform", from: 0.0, to: Double.pi)
    rotation.valueFunction = CAValueFunction(name: .rotateZ)

    let cases: [(name: String, keyPath: String, animation: CAAnimation)] = [
      ("a keyframe animation", "backgroundColor", keyframeAnimation),
      ("a by value", "backgroundColor", byAnimation),
      ("an unresolved from value", "backgroundColor", animation(keyPath: "backgroundColor", from: NSNull(), to: blue)),
      ("an unresolved to value", "backgroundColor", animation(keyPath: "backgroundColor", from: red, to: NSNull())),
      ("no to value", "backgroundColor", animation(keyPath: "backgroundColor", from: red, to: nil)),
      ("a repeat", "backgroundColor", repeatingAnimation),
      ("a repeat that begins later with a backwards fill", "backgroundColor", laterRepeatingAnimation),
      ("values of other kinds", "shadowOffset", animation(keyPath: "shadowOffset", from: 1.0, to: CGSize(width: 8, height: 4))),
      ("a pattern color", "backgroundColor", animation(keyPath: "backgroundColor", from: red, to: patternColor)),
      ("paths of other segments", "shadowPath", animation(keyPath: "shadowPath", from: square, to: ellipse)),
      ("an additive color", "backgroundColor", animation(keyPath: "backgroundColor", from: red, to: blue, isAdditive: true)),
      ("an additive number over a size", "shadowOffset", animation(keyPath: "shadowOffset", from: 1.0, to: 0.0, isAdditive: true)),
      ("an opacity keyframe animation", "opacity", opacityKeyframeAnimation),
      ("an opacity by value", "opacity", opacityByAnimation),
      ("an opacity from a color", "opacity", animation(keyPath: "opacity", from: red, to: 1.0)),
      ("an opacity to a color", "opacity", animation(keyPath: "opacity", from: 0.0, to: red)),
      ("a repeating opacity", "opacity", repeatingOpacityAnimation),
      ("a value function", "transform", rotation),
      ("a group", "backgroundColor", group(of: [CABasicAnimation(keyPath: "backgroundColor")])),
      ("a group in a group", "backgroundColor", group(of: [group(of: [CABasicAnimation(keyPath: "backgroundColor")])])),
      ("an opacity group", "opacity", group(of: [CABasicAnimation(keyPath: "opacity")])),
      ("a component key path", "position", animation(keyPath: "position.x", from: 0.0, to: 10.0)),
      ("a parent key path", "bounds.size", animation(keyPath: "bounds", from: CGRect(x: 0, y: 0, width: 10, height: 10), to: CGRect(x: 0, y: 0, width: 20, height: 20))),
      ("a group of a component key path", "position", group(of: [CABasicAnimation(keyPath: "position.x")])),
    ]
    for testCase in cases {
      // given: a red layer without a presentation layer, with an animation that can't be evaluated
      let layer = CALayer()
      layer.backgroundColor = red
      layer.add(testCase.animation, forKey: "unevaluable")

      // when: reading the key path at 1000.5
      let shown = AnimationClock.sharingTime(at: 1000.5) {
        layer.shownValue(forKeyPath: testCase.keyPath)
      }

      // then: it's the presentation value, which the layer doesn't have
      expect(shown, testCase.name) == nil
    }
  }

  func test_shownValue_unevaluableAnimation_isThePresentationValue() throws {
    // given: a hosted red layer with a keyframe animation of its background color that holds green
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    layer.backgroundColor = red
    testWindow.layer.addSublayer(layer)
    let green = CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
    let keyframeAnimation = CAKeyframeAnimation(keyPath: "backgroundColor")
    keyframeAnimation.values = [green, green]
    keyframeAnimation.duration = 100
    layer.add(keyframeAnimation, forKey: "keyframes")
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: reading the background color
    let shown = layer.shownValue(forKeyPath: "backgroundColor")

    // then: the animation can't be evaluated, so it's the color the presentation layer shows
    try expectExtendedSRGBComponents(of: colorValue(shown), toBe: [0, 1, 0, 1])
  }

  // MARK: - Core Animation

  func test_shownValue_matchesThePresentationLayer() throws {
    // given: layers on a paused timeline, with stacks of animations from 100 over 10 s, of values the render server
    // doesn't clamp, so the presentation layer reports what shows
    let testWindow = TestWindow()
    let root = CALayer()
    root.speed = 0
    root.timeOffset = 100
    testWindow.layer.addSublayer(root)
    CATransaction.flush()

    func basicAnimation(_ keyPath: String, from: Any, to: Any, beginTime: TimeInterval = 100, isAdditive: Bool = false, timingFunction: CAMediaTimingFunction? = nil) -> CABasicAnimation {
      let animation = CABasicAnimation(keyPath: keyPath)
      animation.fromValue = from
      animation.toValue = to
      animation.beginTime = beginTime
      animation.duration = 10
      animation.timingFunction = timingFunction
      animation.fillMode = .both
      animation.isAdditive = isAdditive
      return animation
    }

    // a slow, bouncy spring, still well away from landing at the times compared
    let spring = CASpringAnimation(keyPath: "position")
    spring.fromValue = CGPoint(x: -40, y: 20)
    spring.toValue = CGPoint.zero
    spring.isAdditive = true
    spring.stiffness = 10
    spring.damping = 1
    spring.beginTime = 100
    spring.duration = 10
    spring.fillMode = .both

    let cases: [(keyPath: String, model: Any, animations: [CABasicAnimation])] = [
      ("backgroundColor", blue, [basicAnimation("backgroundColor", from: red, to: blue, timingFunction: CAMediaTimingFunction(name: .easeInEaseOut))]),
      ("position", CGPoint(x: 50, y: 50), [spring]),
      ("borderWidth", 4.0, [basicAnimation("borderWidth", from: 2.0, to: 0.0, isAdditive: true), basicAnimation("borderWidth", from: -1.0, to: 0.0, isAdditive: true)]),
      ("shadowRadius", 10.0, [basicAnimation("shadowRadius", from: 4.0, to: 0.0, isAdditive: true), basicAnimation("shadowRadius", from: 2.0, to: 10.0)]),
      ("shadowOffset", CGSize(width: 1, height: 1), [basicAnimation("shadowOffset", from: CGSize(width: 4, height: 4), to: CGSize(width: 1, height: 1), beginTime: 104)]),
      ("opacity", Float(0.5), [basicAnimation("opacity", from: 0.2, to: 0.0, isAdditive: true)]),
      ("cornerRadius", 10.0, [basicAnimation("cornerRadius", from: -4.0, to: 0.0, isAdditive: true)]),
      ("shadowPath", CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil), [basicAnimation("shadowPath", from: CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil), to: CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil))]),
    ]
    // each stack is on a hosted layer, which Core Animation shows, and on a detached twin, which the value is computed
    // for, since the twin has no presentation layer for the computation to fall back to
    func makeLayer(for testCase: (keyPath: String, model: Any, animations: [CABasicAnimation])) -> CALayer {
      let layer = CALayer()
      layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
      // without implicit animations, which the stacks would include
      CATransaction.disableAnimations {
        layer.setValue(testCase.model, forKeyPath: testCase.keyPath)
      }
      for (index, animation) in testCase.animations.enumerated() {
        layer.add(animation, forKey: "\(testCase.keyPath)-\(index)")
      }
      return layer
    }
    let hostedLayers = cases.map { testCase -> CALayer in
      let layer = makeLayer(for: testCase)
      root.addSublayer(layer)
      return layer
    }

    for time in [103.0, 106.0] {
      // when: moving the timeline
      root.timeOffset = time
      CATransaction.flush()

      for (testCase, hostedLayer) in zip(cases, hostedLayers) {
        // then: the computed value is the one the presentation layer shows, within Core Animation's single precision
        // solving of timing functions and springs. the twin is made after the commit, which drops a detached layer's
        // animations
        let description = "\(testCase.keyPath) at \(time)"
        let shown = try unwrap(hostedLayer.presentation()?.value(forKeyPath: testCase.keyPath), description)
        let twin = makeLayer(for: testCase)
        let computed = try unwrap(twin.shownValue(forKeyPath: testCase.keyPath, animations: twin.propertyAnimations(forKeyPath: testCase.keyPath).map(KeyPathAnimation.direct), at: time), description)
        switch testCase.keyPath {
        case "backgroundColor":
          try expectExtendedSRGBComponents(of: colorValue(computed), toBe: colorValue(shown).extendedSRGBComponents(), within: 1e-4)
        case "position":
          let point = try unwrap(computed as? CGPoint, description)
          let shownPoint = try unwrap(shown as? CGPoint, description)
          expect(point.x, description).to(beApproximatelyEqual(to: shownPoint.x, within: 1e-3))
          expect(point.y, description).to(beApproximatelyEqual(to: shownPoint.y, within: 1e-3))
        case "shadowOffset":
          let size = try unwrap(computed as? CGSize, description)
          let shownSize = try unwrap(shown as? CGSize, description)
          expect(size.width, description).to(beApproximatelyEqual(to: shownSize.width, within: 1e-4))
          expect(size.height, description).to(beApproximatelyEqual(to: shownSize.height, within: 1e-4))
        case "shadowPath":
          expect(try pathValue(computed).boundingBoxOfPath.width, description).to(try beApproximatelyEqual(to: pathValue(shown).boundingBoxOfPath.width, within: 1e-4))
          expect(try pathValue(computed).boundingBoxOfPath.height, description).to(try beApproximatelyEqual(to: pathValue(shown).boundingBoxOfPath.height, within: 1e-4))
        default:
          expect(try numberScalar(computed), description).to(try beApproximatelyEqual(to: numberScalar(shown), within: 1e-4))
        }
      }
    }
  }

  #if canImport(AppKit)
  func test_shownValue_clampedNumbers_matchWhatRenders() throws {
    // given: a rendered white layer at 0.5 opacity with additive opacity animations from 0.8 and from -0.3 to 0, over two
    // seconds from 10
    let opacityRenderer = try PausedLayerRenderer(time: 10)
    let opacityLayer = opacityRenderer.layer
    opacityLayer.disableActions(for: "opacity") {
      opacityLayer.opacity = 0.5
    }
    opacityLayer.add(animation(keyPath: "opacity", from: 0.8, to: 0.0, beginTime: 10, isAdditive: true), forKey: "a")
    opacityLayer.add(animation(keyPath: "opacity", from: -0.3, to: 0.0, beginTime: 10, isAdditive: true), forKey: "b")

    // when: moving the timeline a quarter of the way
    opacityRenderer.move(to: 10.5)

    // then: the computed opacity, clamped after each animation, is the one that renders, while the presentation layer
    // reports the unclamped sum
    let opacity = try unwrap(opacityLayer.shownValue(forKeyPath: "opacity", animations: opacityLayer.propertyAnimations(forKeyPath: "opacity").map(KeyPathAnimation.direct), at: 10.5) as? Float)
    expect(Double(opacity)).to(beApproximatelyEqual(to: 0.775, within: 1e-6))
    expect(opacityRenderer.renderedOpacity()).to(beApproximatelyEqual(to: Double(opacity), within: 0.01))
    expect(try Double(unwrap(opacityLayer.presentation()).opacity)).to(beApproximatelyEqual(to: 0.875, within: 1e-6))

    // given: a rendered white layer with a corner radius of 2 and additive animations from -4 and from 2 to 0, beginning
    // at 10
    let radiusRenderer = try PausedLayerRenderer(time: 10)
    let radiusLayer = radiusRenderer.layer
    radiusLayer.disableActions(for: "cornerRadius") {
      radiusLayer.cornerRadius = 2
    }
    radiusLayer.add(animation(keyPath: "cornerRadius", from: -4.0, to: 0.0, beginTime: 10, isAdditive: true), forKey: "a")
    radiusLayer.add(animation(keyPath: "cornerRadius", from: 2.0, to: 0.0, beginTime: 10, isAdditive: true), forKey: "b")

    // when: reading the corner radius as they begin, and rendering the corner's pixel
    let radius = try unwrap(radiusLayer.shownValue(forKeyPath: "cornerRadius", animations: radiusLayer.propertyAnimations(forKeyPath: "cornerRadius").map(KeyPathAnimation.direct), at: 10) as? CGFloat)
    let renderedCorner = radiusRenderer.renderedOpacity(x: 0, y: 0)

    // then: the computed radius, clamped at 0 after each animation, is 2, and the corner renders as a still corner of that
    // radius does, instead of the square corner of the unclamped sum 0
    expect(radius) == 2
    radiusLayer.removeAllAnimations()
    radiusLayer.disableActions(for: "cornerRadius") {
      radiusLayer.cornerRadius = radius
    }
    expect(radiusRenderer.renderedOpacity(x: 0, y: 0)).to(beApproximatelyEqual(to: renderedCorner, within: 0.01))
    radiusLayer.disableActions(for: "cornerRadius") {
      radiusLayer.cornerRadius = 0
    }
    expect(radiusRenderer.renderedOpacity(x: 0, y: 0)) > renderedCorner + 0.1
  }
  #endif

  // MARK: - Helpers

  /// A basic animation from a value to a value over two seconds, linear, from a begin time, with a backwards and a
  /// forwards fill.
  private func animation(keyPath: String, from: Any?, to: Any?, beginTime: TimeInterval = 1000, isAdditive: Bool = false) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: keyPath)
    animation.fromValue = from
    animation.toValue = to
    animation.beginTime = beginTime
    animation.duration = 2
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    animation.fillMode = .both
    animation.isAdditive = isAdditive
    return animation
  }

  /// A group of animations over two seconds from 1000, with a backwards and a forwards fill.
  private func group(of animations: [CAAnimation]) -> CAAnimationGroup {
    let group = CAAnimationGroup()
    group.animations = animations
    group.beginTime = 1000
    group.duration = 2
    group.fillMode = .both
    return group
  }
}
