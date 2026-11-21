//
//  CALayer+CrossfadeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/20/26.
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

class CALayer_CrossfadeTests: XCTestCase {

  func test_animateCrossfade_timingFunction() throws {
    // given: a layer
    let layer = CALayer()

    // when: at the media time 1000, crossfading the layer with a timing function
    AnimationClock.sharingTime(at: 1000) {
      layer.animateCrossfade(timing: .easeIn(duration: 2))
    }

    // then: the layer fades for the timing's duration, along its timing function, from the clock's time, and fills both
    // ways, as an animation of the timing does
    let transition = try unwrap(layer.animation(forKey: kCATransition) as? CATransition)
    expect(transition.type) == .fade
    expect(transition.duration) == 2
    expect(transition.timingFunction) == CAMediaTimingFunction(name: .easeIn)
    expect(transition.speed) == 1
    expect(transition.fillMode) == .both
    expect(transition.beginTime) == 1000
  }

  func test_animateCrossfade_spring() throws {
    // given: a layer
    let layer = CALayer()
    let spring = SpringDescriptor(dampingRatio: 0.8, response: 0.4)

    // when: crossfading the layer with a spring without a duration
    layer.animateCrossfade(timing: .spring(dampingRatio: 0.8, response: 0.4))

    // then: the layer fades for the spring's duration, along an ease-out curve
    let transition = try unwrap(layer.animation(forKey: kCATransition) as? CATransition)
    expect(transition.duration).to(beApproximatelyEqual(to: spring.perceptualDuration(), within: 1e-9))
    expect(transition.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    // when: crossfading the layer with a spring with a duration
    layer.animateCrossfade(timing: .spring(dampingRatio: 0.8, response: 0.4, duration: 3))

    // then: the crossfade replaces the one in flight, and fades for the given duration
    let replacingTransition = try unwrap(layer.animation(forKey: kCATransition) as? CATransition)
    expect(layer.animationKeys()) == [kCATransition]
    expect(replacingTransition.duration) == 3
    expect(replacingTransition.timingFunction) == CAMediaTimingFunction(name: .easeOut)
  }

  func test_animateCrossfade_delayAndSpeed() throws {
    // given: a layer in a layer tree whose time runs at twice the media time
    let root = CALayer()
    root.speed = 2
    let layer = CALayer()
    root.addSublayer(layer)

    // when: at the media time 1000, crossfading the layer after a delay, at a speed
    AnimationClock.sharingTime(at: 1000) {
      layer.animateCrossfade(timing: .linear(duration: 1, delay: 0.5, speed: 3))
    }

    // then: the fade begins after the delay, in the layer's time space, at the timing's speed
    let transition = try unwrap(layer.animation(forKey: kCATransition) as? CATransition)
    expect(transition.beginTime) == 2000.5
    expect(transition.speed) == 3
    expect(transition.duration) == 1
  }

  func test_animateCrossfade_zeroDuration() throws {
    // given: a layer
    let layer = CALayer()

    // when: crossfading the layer with a zero duration
    layer.animateCrossfade(timing: .linear(duration: 0))

    // then: the layer changes at once
    expect(layer.animationKeys()) == nil

    // when: at the media time 1000, crossfading the layer with a zero duration after a delay, at a speed
    AnimationClock.sharingTime(at: 1000) {
      layer.animateCrossfade(timing: .linear(duration: 0, delay: 0.5, speed: 3))
    }

    // then: the layer changes after the delay, in a fade shorter than a frame at the normal speed
    let transition = try unwrap(layer.animation(forKey: kCATransition) as? CATransition)
    expect(transition.beginTime) == 1000.5
    expect(transition.duration) == 0.001
    expect(transition.speed) == 1
  }

  #if canImport(AppKit)
  func test_animateCrossfade_rendersABlend() throws {
    // given: a white layer over black, on a timeline paused at 10
    let renderer = try PausedLayerRenderer(time: 10)
    let layer = renderer.layer

    // when: the layer turns black in a linear crossfade of 10 seconds
    layer.disableActions(for: "backgroundColor") {
      layer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    layer.animateCrossfade(timing: .linear(duration: 10))

    // then: the layer shows white at the start, a blend of white and black halfway, and black at the end
    for (time, white) in [(10.0, 1.0), (15.0, 0.5), (20.0, 0.0)] {
      renderer.move(to: time)
      expect(renderer.renderedOpacity(), "\(time)").to(beApproximatelyEqual(to: white, within: 0.01))
    }
  }

  func test_animateCrossfade_inFlight_startsFromTheLastCommit() throws {
    // given: a white layer over black, on a timeline paused at 10, halfway through a linear crossfade of 10 seconds to
    // black
    let renderer = try PausedLayerRenderer(time: 10)
    let layer = renderer.layer
    layer.disableActions(for: "backgroundColor") {
      layer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    layer.animateCrossfade(timing: .linear(duration: 10))
    renderer.move(to: 10)
    renderer.move(to: 15)
    expect(renderer.renderedOpacity()).to(beApproximatelyEqual(to: 0.5, within: 0.01))

    // when: the layer turns white again in another linear crossfade of 10 seconds
    layer.disableActions(for: "backgroundColor") {
      layer.backgroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    }
    layer.animateCrossfade(timing: .linear(duration: 10))

    // then: the crossfade replaces the one in flight, and fades from black, what the layer showed at the last commit
    expect(layer.animationKeys()) == [kCATransition]
    for (time, white) in [(15.0, 0.0), (20.0, 0.5), (25.0, 1.0)] {
      renderer.move(to: time)
      expect(renderer.renderedOpacity(), "\(time)").to(beApproximatelyEqual(to: white, within: 0.01))
    }
  }

  func test_animateCrossfade_zeroDuration_endsTheCrossfadeInFlight() throws {
    for (name, inFlightTiming, time) in [
      ("delayed crossfade", AnimationTiming.linear(duration: 10, delay: 5), 12.0),
      ("fading crossfade", AnimationTiming.linear(duration: 10), 15.0),
    ] {
      // given: a white layer over black, on a timeline paused at 10, with a crossfade to black in flight
      let renderer = try PausedLayerRenderer(time: 10)
      let layer = renderer.layer
      layer.disableActions(for: "backgroundColor") {
        layer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
      }
      layer.animateCrossfade(timing: inFlightTiming)
      renderer.move(to: 10)
      renderer.move(to: time)

      // when: the layer turns gray with a zero duration and no delay
      layer.disableActions(for: "backgroundColor") {
        layer.backgroundColor = CGColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
      }
      layer.animateCrossfade(timing: .linear(duration: 0))

      // then: the crossfade in flight ends, and the layer shows gray at once, as after the crossfade would have ended
      expect(layer.animationKeys(), name) == nil
      renderer.move(to: 25)
      let gray = renderer.renderedOpacity()
      expect(gray, name).to(beBetween(0.2, and: 0.4))
      for renderTime in [time, time + 2] {
        renderer.move(to: renderTime)
        expect(renderer.renderedOpacity(), "\(name) at \(renderTime)").to(beApproximatelyEqual(to: gray, within: 0.01))
      }
    }
  }

  func test_animateCrossfade_delayed_showsTheOldRenderingUntilTheDelayEnds() throws {
    // given: a white layer over black, on a timeline paused at 10
    let renderer = try PausedLayerRenderer(time: 10)
    let layer = renderer.layer

    // when: the layer turns black in a linear crossfade of 10 seconds after a delay of 5 seconds
    layer.disableActions(for: "backgroundColor") {
      layer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    layer.animateCrossfade(timing: .linear(duration: 10, delay: 5))

    // then: the layer shows white until the delay ends, then fades to black
    for (time, white) in [(10.0, 1.0), (14.0, 1.0), (20.0, 0.5), (25.0, 0.0)] {
      renderer.move(to: time)
      expect(renderer.renderedOpacity(), "\(time)").to(beApproximatelyEqual(to: white, within: 0.01))
    }
  }
  #endif
}
