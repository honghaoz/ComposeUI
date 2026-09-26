//
//  ModifierNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
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

class ModifierNodeTests: XCTestCase {

  // MARK: - ComposeNode

  func test_id() {
    // test that id property delegates to underlying node

    // given: a modifier node wrapping a base node
    let baseNode = ViewNode()
    let originalId = baseNode.id

    let modifierNode = baseNode.opacity(0.5)

    // then: the initial id should match the base node
    expect(modifierNode.id) == originalId

    // when: setting a new id on the modifier node
    // setting id on modifier should affect the inner node, hence the renderable items
    let newId = ComposeNodeId.custom("new")
    var mutableModifierNode = modifierNode
    mutableModifierNode.id = newId

    // then: the modifier node reports the new id
    expect(mutableModifierNode.id) == newId

    // when: laying out and getting renderable items
    let containerSize = CGSize(width: 100, height: 50)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    mutableModifierNode.layout(containerSize: containerSize, context: context)
    let renderableItems = mutableModifierNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the renderable items use the new id
    expect(renderableItems.first?.id) == newId
  }

  func test_size() {
    // test that size property delegates to underlying node

    // initial size should be zero
    do {
      // given: a modifier node on a base node without layout
      let baseNode = ViewNode()
      let modifierNode = baseNode.opacity(0.5)

      // then: the size is zero, matching the base node
      expect(modifierNode.size) == .zero
      expect(modifierNode.size) == baseNode.size
    }

    // modifier node with pre-layout node
    do {
      // given: a modifier node on a laid out base node
      var baseNode = ViewNode()

      let containerSize = CGSize(width: 100, height: 50)
      let context = ComposeNodeLayoutContext(scaleFactor: 2)

      _ = baseNode.layout(containerSize: containerSize, context: context)

      let modifierNode = baseNode.opacity(0.5)

      // then: the size matches the laid out base node
      expect(modifierNode.size) == containerSize
      expect(modifierNode.size) == baseNode.size
    }
  }

  // MARK: - Life cycle calls

  func test_lifeCycleCalls() {
    // given: a view node with many modifiers
    var willInsertCalls: [String] = []
    var didInsertCalls: [String] = []
    var willUpdateCalls: [String] = []
    var updateCalls: [String] = []
    var willRemoveCalls: [String] = []
    var didRemoveCalls: [String] = []

    let node = ViewNode()
      .willInsert { _, _ in willInsertCalls.append("first") }
      .onInsert { _, _ in didInsertCalls.append("first") }
      .willUpdate { _, _ in willUpdateCalls.append("first") }
      .onUpdate { _, _ in updateCalls.append("first") }
      .willRemove { _, _ in willRemoveCalls.append("first") }
      .onRemove { _, _ in didRemoveCalls.append("first") }
      .willInsert { _, _ in willInsertCalls.append("second") }
      .onInsert { _, _ in didInsertCalls.append("second") }
      .willUpdate { _, _ in willUpdateCalls.append("second") }
      .onUpdate { _, _ in updateCalls.append("second") }
      .willRemove { _, _ in willRemoveCalls.append("second") }
      .onRemove { _, _ in didRemoveCalls.append("second") }

    // then: the modifiers are coalescing
    expect(
      String(describing: node).hasPrefix("ModifierNode(node: ComposeUI.ViewNode<")
    ) == true

    // when: the compose view is refreshed
    let composeView = ComposeView { node }
    composeView.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

    composeView.refresh(animated: false)

    // then: the modifier calls are called in order
    expect(willInsertCalls) == ["first", "second"]
    expect(didInsertCalls) == ["first", "second"]
    expect(willUpdateCalls) == ["first", "second"]
    expect(updateCalls) == ["first", "second"]
    expect(willRemoveCalls) == []
    expect(didRemoveCalls) == []

    // when: the content is removed
    composeView.setContent { Empty() }
    composeView.refresh(animated: false)

    // then: the remove modifier calls are called in order
    expect(willInsertCalls) == ["first", "second"]
    expect(didInsertCalls) == ["first", "second"]
    expect(willUpdateCalls) == ["first", "second"]
    expect(updateCalls) == ["first", "second"]
    expect(willRemoveCalls) == ["first", "second"]
    expect(didRemoveCalls) == ["first", "second"]
  }

  // MARK: - Animation

  func test_animation() {
    // given: a view node with multiple animations
    let expectation = expectation(description: "animation")

    var updateCount = 0
    let node = ViewNode()
      .animation(.easeInEaseOut(duration: 1))
      .animation(.easeInEaseOut(duration: 2))
      .onUpdate { View, context in
        updateCount += 1
        switch updateCount {
        case 1:
          // initial insert update
          expect(context.animationTiming) == nil
        case 2:
          // then the inner animation is used
          expect(
            context.animationTiming?.timing
          ) == .timingFunction(1, CAMediaTimingFunction(name: .easeInEaseOut))
          expectation.fulfill()
        default:
          fail("Unexpected update count: \(updateCount)")
        }
      }

    // when: the compose view is refreshed twice
    let composeView = ComposeView { node }
    composeView.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

    composeView.refresh(animated: true)
    composeView.refresh(animated: true)

    // then: the second update uses the inner animation timing
    wait(for: [expectation], timeout: 1)
  }

  // MARK: - Transition

  func test_transition() {
    // basic transition
    do {
      // given: a layer node with a custom transition
      var insertionCompleted = false
      var removalCompleted = false

      let transition = RenderableTransition(
        insert: RenderableTransition.InsertTransition { renderable, context, completion in
          renderable.setFrame(context.targetFrame)
          insertionCompleted = true
          completion()
        },
        remove: RenderableTransition.RemoveTransition { renderable, context, completion in
          removalCompleted = true
          completion()
        }
      )

      let contentView = ComposeView {
        LayerNode()
          .transition(transition)
      }

      // when: the view is sized and refreshed animated
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)

      // then: the insert transition is performed
      expect(insertionCompleted) == true
      expect(removalCompleted) == false

      // when: the content is removed to test the removal transition
      contentView.setContent { Empty() }
      contentView.refresh(animated: true)

      // then: the remove transition is performed
      expect(insertionCompleted) == true
      expect(removalCompleted) == true
    }

    // multiple transitions (inner one wins)
    do {
      // given: a layer node with two transitions
      var firstTransitionUsed = false
      var secondTransitionUsed = false

      let firstTransition = RenderableTransition(
        insert: RenderableTransition.InsertTransition { renderable, context, completion in
          renderable.setFrame(context.targetFrame)
          firstTransitionUsed = true
          completion()
        },
        remove: RenderableTransition.RemoveTransition { renderable, context, completion in
          completion()
        }
      )

      let secondTransition = RenderableTransition(
        insert: RenderableTransition.InsertTransition { renderable, context, completion in
          renderable.setFrame(context.targetFrame)
          secondTransitionUsed = true
          completion()
        },
        remove: RenderableTransition.RemoveTransition { renderable, context, completion in
          completion()
        }
      )

      let contentView = ComposeView {
        LayerNode()
          .transition(firstTransition) // this should win
          .transition(secondTransition)
      }

      // when: the view is sized and refreshed animated
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)

      // then: only the inner transition is used
      expect(firstTransitionUsed) == true
      expect(secondTransitionUsed) == false
    }

    // predefined opacity transition
    do {
      // given: a layer node with the predefined opacity transition
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .transition(.opacity(from: 0, to: 1, timing: .easeInEaseOut(duration: 0.1)))
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)

      // then: the layer should eventually have full opacity after the transition
      expect(layer?.opacity).toEventually(beEqual(to: 1.0))
    }
  }

  // MARK: - Background Color

  func test_backgroundColor() {
    // solid color
    do {
      // given: a layer node with a solid background color
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(.red)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer has the background color
      expect(layer?.backgroundColor) == Color.red.cgColor
    }

    // themed color
    do {
      // given: a layer node with a themed background color
      var layer: CALayer?
      let themedColor = ThemedColor(light: .blue, dark: .green)
      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(themedColor)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

      // when: refreshed with the dark theme
      contentView.overrideTheme = .dark
      contentView.refresh()

      // then: the layer uses the dark color
      expect(layer?.backgroundColor) == Color.green.cgColor

      // when: refreshed with the light theme
      contentView.overrideTheme = .light
      contentView.refresh()

      // then: the layer uses the light color
      expect(layer?.backgroundColor) == Color.blue.cgColor
    }

    // multiple modifiers (last one wins)
    do {
      // given: a layer node with two background color modifiers
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(.red)
          .backgroundColor(.blue) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the last background color wins
      expect(layer?.backgroundColor) == Color.blue.cgColor
    }

    // with animation
    do {
      // given: a layer node with a background color and an animation
      var layer: CALayer?
      var color: Color = .red
      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(color)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated, then refreshed animated with a new color
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      color = .blue
      contentView.refresh(animated: true)

      // then: the layer animates to the new color
      expect(layer?.backgroundColor) == Color.blue.cgColor
      expect(layer?.animationKeys()?.contains("backgroundColor")) == true
    }

    // bounds changes keep configuration
    do {
      // given: a layer node with a captured background color
      var layer: CALayer?
      var color: Color = .red

      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(color)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer has the initial color
      expect(layer?.backgroundColor) == Color.red.cgColor

      // when: the bounds change with a new color set
      color = .blue
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the frame changes but the configured color is kept
      expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      expect(layer?.backgroundColor) == Color.red.cgColor
      expect(layer?.animation(forKey: "backgroundColor")) == nil

      // when: the view is refreshed with a new color set
      color = .green
      contentView.refresh()

      // then: the refresh should set the new color
      expect(layer?.backgroundColor) == Color.green.cgColor
    }
  }

  // MARK: - Opacity

  func test_opacity() {
    // normal opacity value
    do {
      // given: a layer node with an opacity modifier
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .opacity(0.5)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer has the opacity
      expect(layer?.opacity) == 0.5
    }

    // themed opacity
    do {
      // given: a layer node with a themed opacity
      var layer: CALayer?
      let themedOpacity = Themed<CGFloat>(light: 0.8, dark: 0.3)
      let contentView = ComposeView {
        LayerNode()
          .opacity(themedOpacity)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

      // when: refreshed with the light theme
      contentView.overrideTheme = .light
      contentView.refresh()

      // then: the layer uses the light opacity
      expect(layer?.opacity) == 0.8

      // when: refreshed with the dark theme
      contentView.overrideTheme = .dark
      contentView.refresh()

      // then: the layer uses the dark opacity
      expect(layer?.opacity) == 0.3
    }

    // multiple modifiers (last one wins)
    do {
      // given: a layer node with two opacity modifiers
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .opacity(0.3)
          .opacity(0.7) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the last opacity wins
      expect(layer?.opacity) == 0.7
    }

    // with animation
    do {
      // given: a layer node with an opacity and an animation
      var layer: CALayer?
      var opacity: CGFloat = 0.6
      let contentView = ComposeView {
        LayerNode()
          .opacity(opacity)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated, then refreshed animated with a new opacity
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      opacity = 0.3
      contentView.refresh(animated: true)

      // then: the layer animates to the new opacity
      expect(layer?.opacity) == 0.3
      expect(layer?.animationKeys()?.contains("opacity")) == true
    }

    // bounds changes keep configuration
    do {
      // given: a layer node with a captured opacity
      var layer: CALayer?
      var opacity: CGFloat = 0.5

      let contentView = ComposeView {
        LayerNode()
          .opacity(opacity)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer has the initial opacity
      expect(layer?.opacity) == 0.5

      // when: the bounds change with a new opacity set
      opacity = 0.8
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the frame changes but the configured opacity is kept
      expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      expect(layer?.opacity) == 0.5
      expect(layer?.animation(forKey: "opacity")) == nil

      // when: the view is refreshed with a new opacity set
      opacity = 0.3
      contentView.refresh()

      // then: the refresh should set the new opacity
      expect(layer?.opacity) == 0.3
    }
  }

  // MARK: - Border

  func test_border() {
    // basic border
    do {
      // given: a layer node with a border
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .border(color: .red, width: 2)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer has the border color and width
      expect(layer?.borderColor) == Color.red.cgColor
      expect(layer?.borderWidth) == 2
    }

    // themed border
    do {
      // given: a layer node with a themed border
      var layer: CALayer?
      let themedColor = ThemedColor(light: .green, dark: .orange)
      let themedWidth = Themed<CGFloat>(light: 1, dark: 3)
      let contentView = ComposeView {
        LayerNode()
          .border(color: themedColor, width: themedWidth)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

      // when: refreshed with the light theme
      contentView.overrideTheme = .light
      contentView.refresh()

      // then: the layer uses the light border
      expect(layer?.borderColor) == Color.green.cgColor
      expect(layer?.borderWidth) == 1

      // when: refreshed with the dark theme
      contentView.overrideTheme = .dark
      contentView.refresh()

      // then: the layer uses the dark border
      expect(layer?.borderColor) == Color.orange.cgColor
      expect(layer?.borderWidth) == 3
    }

    // multiple modifiers (last one wins)
    do {
      // given: a layer node with two border modifiers
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .border(color: .red, width: 1)
          .border(color: .blue, width: 3) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the last border wins
      expect(layer?.borderColor) == Color.blue.cgColor
      expect(layer?.borderWidth) == 3
    }

    // with animation
    do {
      // given: a layer node with a border and an animation
      var layer: CALayer?
      var color: Color = .cyan
      var width: CGFloat = 4
      let contentView = ComposeView {
        LayerNode()
          .border(color: color, width: width)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated, then refreshed animated with a new border
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      color = .magenta
      width = 6
      contentView.refresh(animated: true)

      // then: the layer animates to the new border
      expect(layer?.borderColor) == Color.magenta.cgColor
      expect(layer?.borderWidth) == 6
      expect(layer?.animationKeys()?.contains("borderColor")) == true
      expect(layer?.animationKeys()?.contains("borderWidth")) == true
    }

    // bounds changes keep configuration
    do {
      // given: a layer node with a captured border
      var layer: CALayer?
      var borderColor: Color = .red
      var borderWidth: CGFloat = 2

      let contentView = ComposeView {
        LayerNode()
          .border(color: borderColor, width: borderWidth)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer has the initial border
      expect(layer?.borderColor) == Color.red.cgColor
      expect(layer?.borderWidth) == 2

      // when: the bounds change with a new border set
      borderColor = .blue
      borderWidth = 5
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the frame changes but the configured border is kept
      expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      expect(layer?.borderColor) == Color.red.cgColor
      expect(layer?.borderWidth) == 2
      expect(layer?.animation(forKey: "borderColor")) == nil
      expect(layer?.animation(forKey: "borderWidth")) == nil

      // when: the view is refreshed with a new border set
      borderColor = .green
      borderWidth = 3
      contentView.refresh()

      // then: the refresh should set the new border
      expect(layer?.borderColor) == Color.green.cgColor
      expect(layer?.borderWidth) == 3
    }
  }

  // MARK: - Corner Radius

  func test_cornerRadius() {
    // default cornerCurve
    do {
      // given: a layer node with a corner radius
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(10)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer has the corner radius with the continuous corner curve
      expect(layer?.cornerRadius) == 10
      expect(layer?.cornerCurve) == .continuous
    }

    // explicit cornerCurve
    do {
      // given: a layer node with a corner radius and an explicit corner curve
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(15, cornerCurve: .circular)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer has the corner radius with the explicit corner curve
      expect(layer?.cornerRadius) == 15
      expect(layer?.cornerCurve) == .circular
    }

    // with animation
    do {
      // given: a layer node with a corner radius and an animation
      var layer: CALayer?
      var radius: CGFloat = 15
      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(radius)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated, then refreshed animated with a new corner radius
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      radius = 25
      contentView.refresh(animated: true)

      // then: the layer animates to the new corner radius
      expect(layer?.cornerRadius) == 25
      expect(layer?.animationKeys()?.contains("cornerRadius")) == true
    }

    // bounds changes keep configuration
    do {
      // given: a layer node with a captured corner radius and curve
      var layer: CALayer?
      var cornerRadius: CGFloat = 10
      var cornerCurve: CALayerCornerCurve = .continuous

      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(cornerRadius, cornerCurve: cornerCurve)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer has the initial corner radius and curve
      expect(layer?.cornerRadius) == 10
      expect(layer?.cornerCurve) == .continuous

      // when: the bounds change with a new corner radius and curve set
      cornerRadius = 20
      cornerCurve = .circular
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the frame changes but the configured corner radius and curve are kept
      expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      expect(layer?.cornerRadius) == 10
      expect(layer?.cornerCurve) == .continuous
      expect(layer?.animation(forKey: "cornerRadius")) == nil

      // when: the view is refreshed with a new corner radius and curve set
      cornerRadius = 8
      cornerCurve = .continuous
      contentView.refresh()

      // then: the refresh applies the new corner radius and curve
      expect(layer?.cornerRadius) == 8
      expect(layer?.cornerCurve) == .continuous
    }
  }

  // MARK: - Masks To Bounds

  func test_masksToBounds() {
    // default value (true)
    do {
      // given: a layer node with the default masksToBounds modifier
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds()
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer masks to bounds
      expect(layer?.masksToBounds) == true
    }

    // explicit true
    do {
      // given: a layer node with masksToBounds enabled explicitly
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(true)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer masks to bounds
      expect(layer?.masksToBounds) == true
    }

    // explicit false
    do {
      // given: a layer node with masksToBounds disabled explicitly
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(false)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer does not mask to bounds
      expect(layer?.masksToBounds) == false
    }

    // update from true to false
    do {
      // given: a layer node with masksToBounds enabled
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(true)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer masks to bounds
      expect(layer?.masksToBounds) == true

      // when: the content is updated to masksToBounds false
      contentView.setContent {
        LayerNode()
          .masksToBounds(false)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }
      contentView.refresh()

      // then: the layer does not mask to bounds
      expect(layer?.masksToBounds) == false
    }

    // multiple modifiers (last one wins)
    do {
      // given: a layer node with two masksToBounds modifiers
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(true)
          .masksToBounds(false) // This should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the last masksToBounds wins
      expect(layer?.masksToBounds) == false
    }

    // bounds changes keep configuration
    do {
      // given: a layer node with a captured masksToBounds
      var layer: CALayer?
      var masksToBounds: Bool = true

      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(masksToBounds)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer has the initial masksToBounds
      expect(layer?.masksToBounds) == true

      // when: the bounds change with a new masksToBounds set
      masksToBounds = false
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the frame changes but the configured mask is kept
      expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      expect(layer?.masksToBounds) == true

      // when: the bounds change with masksToBounds enabled
      masksToBounds = true
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 70)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: another bounds change keeps the configured mask
      expect(layer?.masksToBounds) == true

      // when: the view is refreshed with a new masksToBounds set
      masksToBounds = false
      contentView.refresh()

      // then: the refresh should set the new masksToBounds
      expect(layer?.masksToBounds) == false
    }
  }

  // MARK: - Shadow

  func test_shadow() {
    // basic shadow
    do {
      // given: a layer node with a shadow
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .shadow(color: .red, opacity: 0.5, radius: 4, offset: CGSize(width: 2, height: 2), path: nil)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer has the shadow and does not mask to bounds
      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.5
      expect(layer?.shadowRadius) == 4
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 2)
      expect(layer?.masksToBounds) == false
    }

    // themed shadow
    do {
      // given: a layer node with a themed shadow
      var layer: CALayer?
      let themedColor = ThemedColor(light: .gray, dark: .white)
      let themedOpacity = Themed<CGFloat>(light: 0.3, dark: 0.8)
      let themedRadius = Themed<CGFloat>(light: 2, dark: 6)
      let themedOffset = Themed<CGSize>(light: CGSize(width: 1, height: 1), dark: CGSize(width: 4, height: 4))

      let contentView = ComposeView {
        LayerNode()
          .shadow(color: themedColor, opacity: themedOpacity, radius: themedRadius, offset: themedOffset, path: nil)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

      // when: refreshed with the light theme
      contentView.overrideTheme = .light
      contentView.refresh()

      // then: the layer uses the light shadow
      expect(layer?.shadowColor) == Color.gray.cgColor
      expect(layer?.shadowOpacity) == 0.3
      expect(layer?.shadowRadius) == 2
      expect(layer?.shadowOffset) == CGSize(width: 1, height: 1)
      expect(layer?.shadowPath) == nil

      // when: refreshed with the dark theme
      contentView.overrideTheme = .dark
      contentView.refresh()

      // then: the layer uses the dark shadow
      expect(layer?.shadowColor) == Color.white.cgColor
      expect(layer?.shadowOpacity) == 0.8
      expect(layer?.shadowRadius) == 6
      expect(layer?.shadowOffset) == CGSize(width: 4, height: 4)
      expect(layer?.shadowPath) == nil
    }

    // shadow with custom path
    do {
      // given: a layer node with a shadow using a custom path
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .shadow(color: .blue, opacity: 0.7, radius: 3, offset: .zero, path: { renderable in
            return BezierPath(rect: CGRect(x: 0, y: 0, width: 50, height: 25)).cgPath
          })
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer has the shadow with the custom path
      expect(layer?.shadowColor) == Color.blue.cgColor
      expect(layer?.shadowOpacity) == 0.7
      expect(layer?.shadowRadius) == 3
      expect(layer?.shadowOffset) == .zero
      expect(layer?.shadowPath) == BezierPath(rect: CGRect(x: 0, y: 0, width: 50, height: 25)).cgPath
    }

    // multiple modifiers (last one wins)
    do {
      // given: a layer node with two shadow modifiers
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .shadow(color: .red, opacity: 0.1, radius: 1, offset: .zero, path: nil)
          .shadow(color: .blue, opacity: 0.6, radius: 5, offset: CGSize(width: 2, height: 3), path: nil) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the last shadow wins
      expect(layer?.shadowColor) == Color.blue.cgColor
      expect(layer?.shadowOpacity) == 0.6
      expect(layer?.shadowRadius) == 5
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 3)
    }

    // with animation
    do {
      // given: a layer node with a shadow and an animation
      var layer: CALayer?
      var color: Color = .orange
      var opacity: CGFloat = 0.5
      var radius: CGFloat = 6
      var offset = CGSize(width: 3, height: 3)
      let contentView = ComposeView {
        LayerNode()
          .shadow(color: color, opacity: opacity, radius: radius, offset: offset, path: nil)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated, then refreshed animated with a new shadow
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      color = .purple
      opacity = 0.7
      radius = 9
      offset = CGSize(width: 4, height: 5)
      contentView.refresh(animated: true)

      // then: the layer animates to the new shadow
      expect(layer?.shadowColor) == Color.purple.cgColor
      expect(layer?.shadowOpacity) == 0.7
      expect(layer?.shadowRadius) == 9
      expect(layer?.shadowOffset) == CGSize(width: 4, height: 5)
      expect(layer?.animationKeys()?.contains("shadowColor")) == true
      expect(layer?.animationKeys()?.contains("shadowOpacity")) == true
      expect(layer?.animationKeys()?.contains("shadowRadius")) == true
      expect(layer?.animationKeys()?.contains("shadowOffset")) == true
    }

    // early return when for scroll update
    do {
      // given: a layer node with a captured shadow
      var layer: CALayer?
      var shadowColor: Color = .red
      var shadowOpacity: CGFloat = 0.5
      var shadowRadius: CGFloat = 4
      var shadowOffset: CGSize = CGSize(width: 2, height: 2)

      let contentView = ComposeView {
        LayerNode()
          .shadow(color: shadowColor, opacity: shadowOpacity, radius: shadowRadius, offset: shadowOffset, path: { renderable in
            CGPath(rect: renderable.layer.bounds, transform: nil)
          })
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer has the initial shadow
      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.5
      expect(layer?.shadowRadius) == 4
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 2)
      expect(layer?.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil)

      // when: the view scrolls with a new shadow set
      shadowColor = .blue
      shadowOpacity = 0.8
      shadowRadius = 8
      shadowOffset = CGSize(width: 5, height: 5)
      contentView.frame = CGRect(x: 0, y: 2, width: 100, height: 50)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the scroll should not set the new shadow
      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.5
      expect(layer?.shadowRadius) == 4
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 2)

      // when: the bounds change
      contentView.frame = CGRect(x: 0, y: 2, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the shadow frame and path update while its configuration is kept
      expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      expect(layer?.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 60), transform: nil)
      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.5
      expect(layer?.shadowRadius) == 4
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 2)

      // when: the view is refreshed with a new shadow set
      shadowColor = .red
      shadowOpacity = 0.4
      shadowRadius = 7
      shadowOffset = CGSize(width: 2, height: 3)
      contentView.refresh()

      // then: the refresh should set the new shadow
      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.4
      expect(layer?.shadowRadius) == 7
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 3)
    }
  }

  func test_shadow_boundsChange_updatesPathOnlyForRenderableResize() throws {
    for animationTiming in [nil, AnimationTiming.easeInEaseOut()] {
      // given: a layer with a local shadow path and an external input that requires refresh
      let window = TestWindow()
      let contentView = ComposeView()
      let viewport = CGRect(x: 0, y: 0, width: 200, height: 200)
      let frame = CGRect(x: 0, y: 0, width: 40, height: 40)
      var inset: CGFloat = 0
      var node = LayerNode().shadow(color: .red, opacity: 0.5, radius: 4, offset: .zero, path: { renderable in
        CGPath(rect: renderable.layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
      })
      _ = node.layout(containerSize: frame.size, context: ComposeNodeLayoutContext(scaleFactor: 1))
      let item = try unwrap(node.renderableItems(in: frame).first)
      let renderable = item.make(RenderableMakeContext(initialFrame: frame, contentView: contentView))
      let layer = renderable.layer
      window.layer.addSublayer(layer)

      // when: inserting at the already assigned frame
      item.update(renderable, RenderableUpdateContext(updateType: .insert, oldFrame: frame, newFrame: frame, previousRenderBounds: nil, renderBounds: viewport, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled))

      // then: the initial shadow is applied without a size change
      let initialPath = CGPath(rect: layer.bounds, transform: nil)
      expect(layer.shadowPath) == initialPath
      expect(layer.shadowColor) == Color.red.cgColor
      expect(layer.shadowOpacity) == 0.5
      CATransaction.flush()
      inset = 2

      // when: only the viewport changes, including missing viewport history
      for previousBounds in [viewport, nil] {
        item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: frame, newFrame: frame, previousRenderBounds: previousBounds, renderBounds: CGRect(x: 0, y: 20, width: 300, height: 250), animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

        // then: no path or animation update occurs without a renderable-size change
        expect(layer.shadowPath) == initialPath
        expect(layer.animationKeys()) == nil
      }

      // when: moving the renderable without changing its size
      let movedFrame = frame.offsetBy(dx: 10, dy: 20)
      layer.disableActions { layer.frame = movedFrame }
      item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: frame, newFrame: movedFrame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

      // then: the shadow path remains unchanged during position-only updates
      expect(layer.shadowPath) == initialPath
      expect(layer.animationKeys()) == nil

      // when: each dimension changes without a viewport resize, replacing any preceding path animation
      for size in [CGSize(width: 60, height: 40), CGSize(width: 60, height: 80)] {
        let oldFrame = layer.frame
        let previousPath = layer.presentation()?.shadowPath
        layer.disableActions { layer.frame.size = size }
        item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: oldFrame, newFrame: layer.frame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

        // then: the path is recalculated from the new local bounds
        let expectedPath = CGPath(rect: layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
        expect(layer.shadowPath) == expectedPath
        if animationTiming != nil {
          let animation = try unwrap(layer.animation(forKey: "shadowPath") as? CABasicAnimation)
          expect(try CFEqual(unwrap(animation.fromValue) as CFTypeRef, unwrap(previousPath))) == true
          expect(try CFEqual(unwrap(animation.toValue) as CFTypeRef, expectedPath)) == true
        } else {
          expect(layer.animation(forKey: "shadowPath")) == nil
        }
      }

      // when: explicit refresh changes an external input without changing the renderable's size
      inset = 4
      item.update(renderable, RenderableUpdateContext(updateType: .refresh, oldFrame: layer.frame, newFrame: layer.frame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

      // then: refresh applies the path independently of the size comparison
      expect(layer.shadowPath) == CGPath(rect: layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
      expect(layer.shadowColor) == Color.red.cgColor
      expect(layer.animation(forKey: "shadowPath") != nil) == (animationTiming != nil)
      layer.removeAllAnimations()
    }
  }

  func test_shadows_followRenderableSizeDuringHostUpdates() throws {
    for hasFixedWidth in [true, false] {
      // given: all shadow APIs render local paths with a configurable inset
      var inset: CGFloat = 0
      var directLayer: CALayer?
      var viewLayer: CALayer?
      var dropLayer: CALayer?
      var innerLayer: CALayer?
      var directContext: RenderableUpdateContext?
      let width: FrameSize = hasFixedWidth ? .fixed(40) : .flexible
      let contentView = ComposeView {
        VStack(spacing: 0) {
          LayerNode()
            .shadow(color: .red, opacity: 0.5, radius: 4, offset: .zero, path: { renderable in
              CGPath(rect: renderable.layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
            })
            .frame(width: width, height: 40)
            .onUpdate { renderable, context in
              directLayer = renderable.layer
              directContext = context
            }
          ViewNode<BaseView>()
            .shadow(color: .red, opacity: 0.5, radius: 4, offset: .zero, path: { renderable in
              CGPath(rect: renderable.layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
            })
            .frame(width: width, height: 40)
            .onUpdate { renderable, _ in
              viewLayer = renderable.layer
            }
          DropShadowNode(color: .red, opacity: 0.5, radius: 4, offset: .zero, path: { size in
            CGPath(rect: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset), transform: nil)
          })
          .frame(width: width, height: 40)
          .onUpdate { renderable, _ in
            dropLayer = renderable.layer
          }
          InnerShadowNode(color: .red, opacity: 0.5, radius: 4, offset: .zero, path: { size in
            CGPath(rect: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset), transform: nil)
          })
          .frame(width: width, height: 40)
          .onUpdate { renderable, _ in
            innerLayer = renderable.layer
          }
        }
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
      contentView.refresh(animated: false)
      let layers = try [unwrap(directLayer), unwrap(viewLayer), unwrap(dropLayer), unwrap(innerLayer)]
      let initialWidth: CGFloat = hasFixedWidth ? 40 : 100

      // then: initial insertion configures the path even when the initial frame is already assigned
      for layer in layers {
        expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: initialWidth, height: 40), transform: nil)
        expect(layer.shadowColor) == Color.red.cgColor
      }

      // when: the host resizes while the external path input changes without a refresh
      inset = 2
      contentView.frame.size.width = 200
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: flexible shadows update, while fixed-size shadows keep their old paths
      expect(directContext?.updateType) == .boundsChange
      expect(directLayer) === layers[0]
      expect(viewLayer) === layers[1]
      expect(dropLayer) === layers[2]
      expect(innerLayer) === layers[3]
      let resizedWidth: CGFloat = hasFixedWidth ? 40 : 200
      let expectedInset: CGFloat = hasFixedWidth ? 0 : inset
      for layer in layers {
        let rect = CGRect(x: 0, y: 0, width: resizedWidth, height: 40).insetBy(dx: expectedInset, dy: expectedInset)
        expect(layer.bounds.size) == CGSize(width: resizedWidth, height: 40)
        expect(layer.shadowPath) == CGPath(rect: rect, transform: nil)
      }

      // when: an explicit refresh applies the external input without another size change
      inset = 4
      contentView.refresh(animated: false)

      // then: all shadow APIs apply the new path
      expect(directContext?.updateType) == .refresh
      for layer in layers {
        let rect = CGRect(x: 0, y: 0, width: resizedWidth, height: 40).insetBy(dx: inset, dy: inset)
        expect(layer.shadowPath) == CGPath(rect: rect, transform: nil)
      }
    }
  }

  // MARK: - Z-Index

  func test_zIndex() {
    // the render pass computes the layer's `zPosition` as the z-index band plus a small items-order fraction,
    // so the tests assert the band via `floor`.

    // positive z index
    do {
      // given: a layer node with a z-index
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .zIndex(5)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the layer's z position band matches the z-index
      expect(layer.map { floor($0.zPosition) }) == 5
    }

    // multiple modifiers (the outermost one wins)
    do {
      // given: a layer node with two z-index modifiers
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .zIndex(2)
          .zIndex(8) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the outermost z-index wins
      expect(layer.map { floor($0.zPosition) }) == 8
    }

    // the outermost z-index wins across other modifiers in between
    do {
      // given: a layer node with two z-index modifiers separated by another modifier
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .zIndex(2)
          .frame(width: 50, height: 50)
          .zIndex(8) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the outermost z-index wins
      expect(layer.map { floor($0.zPosition) }) == 8
    }

    // the z-index is re-applied on every render pass
    do {
      // given: a layer node with a captured z-index
      var layer: CALayer?
      var zIndex: CGFloat = 5

      let contentView = ComposeView {
        LayerNode()
          .zIndex(zIndex)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer uses the initial z-index
      expect(layer.map { floor($0.zPosition) }) == 5

      // when: the bounds change with a new z-index set
      zIndex = 10
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the bounds change keeps the configured z-index
      expect(layer.map { floor($0.zPosition) }) == 5

      // when: the view is refreshed with a new z-index set
      zIndex = 3
      contentView.refresh()

      // then: the refresh picks up the new z-index
      expect(layer.map { floor($0.zPosition) }) == 3
    }
  }

  // MARK: - Interactive

  func test_interactive() {
    do {
      // given: a view node with the default interactive modifier
      var view: View?
      let contentView = ComposeView {
        ViewNode()
          .interactive()
          .onInsert { renderable, _ in
            view = renderable.view
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the view is interactive
      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == false
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == true
      #endif
    }

    do {
      // given: a view node with interactive disabled
      var view: View?
      let contentView = ComposeView {
        ViewNode()
          .interactive(false)
          .onInsert { renderable, _ in
            view = renderable.view
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      // then: the view is not interactive
      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == true
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == false
      #endif
    }

    // bounds changes keep configuration
    do {
      // given: a view node with a captured interactive state
      var view: View?
      var isInteractive: Bool = true

      let contentView = ComposeView {
        ViewNode()
          .interactive(isInteractive)
          .onUpdate { renderable, context in
            view = renderable.view
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the view has the initial interactive state
      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == false
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == true
      #endif

      // when: the bounds change with a new interactive state set
      isInteractive = false
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the frame changes but interaction remains enabled
      expect(view?.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == false
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == true
      #endif

      // when: the bounds change with interaction enabled
      isInteractive = true
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 70)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: another bounds change keeps the configured interaction state
      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == false
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == true
      #endif

      // when: the view is refreshed with a new interactive state set
      isInteractive = false
      contentView.refresh()

      // then: the refresh should set the new interactive state
      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == true
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == false
      #endif
    }
  }

  // MARK: - Rasterization

  func test_rasterize() {
    // given: a layer node with rasterization disabled
    var layer: CALayer?
    let contentView = ComposeView {
      LayerNode()
        .rasterize(nil)
        .onInsert { renderable, _ in
          layer = renderable.layer
        }
    }

    // when: the view is sized and refreshed
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    // then: the layer is not rasterized
    expect(layer?.shouldRasterize) == false
    expect(layer?.rasterizationScale) == 1

    // when: the content is updated with a rasterization scale
    contentView.setContent {
      LayerNode()
        .rasterize(3)
        .onInsert { renderable, _ in
          layer = renderable.layer
        }
    }
    contentView.refresh()

    // then: the layer is rasterized with the scale
    expect(layer?.shouldRasterize) == true
    expect(layer?.rasterizationScale) == 3

    // bounds changes keep configuration
    do {
      // given: a layer node with a captured rasterization scale
      var layer: CALayer?
      var rasterizeScale: CGFloat? = 2

      let contentView = ComposeView {
        LayerNode()
          .rasterize(rasterizeScale)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer has the initial rasterize settings
      expect(layer?.shouldRasterize) == true
      expect(layer?.rasterizationScale) == 2

      // when: the bounds change with new rasterize settings set
      rasterizeScale = nil
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the frame changes but the configured rasterization is kept
      expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      expect(layer?.shouldRasterize) == true
      expect(layer?.rasterizationScale) == 2

      // when: the bounds change with rasterization enabled
      rasterizeScale = 3
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 70)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: another bounds change keeps the configured rasterization
      expect(layer?.shouldRasterize) == true
      expect(layer?.rasterizationScale) == 2

      // when: the view is refreshed with new rasterize settings set
      rasterizeScale = nil
      contentView.refresh()

      // then: the refresh should set the new rasterize settings
      expect(layer?.shouldRasterize) == false
      expect(layer?.rasterizationScale) == 1
    }
  }

  // MARK: - Update types

  func test_layerModifiers_boundsChanges_keepProperties() throws {
    for isEnabled in [true, false] {
      // given: a layer with properties that differ from the modifier configuration
      let contentView = ComposeView()
      let layer = CALayer()
      layer.backgroundColor = Color.red.cgColor
      layer.opacity = 0.25
      layer.borderColor = Color.green.cgColor
      layer.borderWidth = 2
      layer.cornerRadius = 10
      layer.cornerCurve = .continuous
      layer.masksToBounds = isEnabled
      layer.shouldRasterize = isEnabled
      layer.rasterizationScale = isEnabled ? 2 : 1
      let item = try firstRenderableItem(
        of: LayerNode()
          .backgroundColor(.blue)
          .opacity(0.75)
          .border(color: .yellow, width: 6)
          .cornerRadius(20, cornerCurve: .circular)
          .masksToBounds(!isEnabled)
          .rasterize(isEnabled ? nil : 3)
      ).unwrap()

      let previousRenderBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      for renderBounds in [previousRenderBounds.offsetBy(dx: 0, dy: 20), CGRect(x: 0, y: 0, width: 100, height: 60)] {
        // when: a bounds change provides an animation timing
        item.update(.layer(layer), RenderableUpdateContext(
          updateType: .boundsChange,
          oldFrame: item.frame,
          newFrame: CGRect(x: 0, y: 0, width: 100, height: 60),
          previousRenderBounds: previousRenderBounds,
          renderBounds: renderBounds,
          animationTiming: .easeInEaseOut(duration: 1),
          contentView: contentView,
          contentEvaluation: nil,
          animationDecision: ComposeView.AnimationDecision.all
        ))

        // then: every property is kept without adding animations
        expect(layer.backgroundColor) == Color.red.cgColor
        expect(layer.opacity) == 0.25
        expect(layer.borderColor) == Color.green.cgColor
        expect(layer.borderWidth) == 2
        expect(layer.cornerRadius) == 10
        expect(layer.cornerCurve) == .continuous
        expect(layer.masksToBounds) == isEnabled
        expect(layer.shouldRasterize) == isEnabled
        expect(layer.rasterizationScale) == (isEnabled ? 2 : 1)
        expect(layer.animationKeys()) == nil
      }

      // when: the same item receives an explicit refresh
      item.update(.layer(layer), RenderableUpdateContext(
        updateType: .refresh,
        oldFrame: item.frame,
        newFrame: item.frame,
        previousRenderBounds: .zero,
        renderBounds: .zero,
        animationTiming: nil,
        contentView: contentView,
        contentEvaluation: nil,
        animationDecision: ComposeView.AnimationDecision.disabled
      ))

      // then: refresh applies every configured property without animation
      expect(layer.backgroundColor) == Color.blue.cgColor
      expect(layer.opacity) == 0.75
      expect(layer.borderColor) == Color.yellow.cgColor
      expect(layer.borderWidth) == 6
      expect(layer.cornerRadius) == 20
      expect(layer.cornerCurve) == .circular
      expect(layer.masksToBounds) == !isEnabled
      expect(layer.shouldRasterize) == !isEnabled
      expect(layer.rasterizationScale) == (isEnabled ? 1 : 3)
      expect(layer.animationKeys()) == nil
    }
  }

  func test_layerModifiers_refresh_animated() throws {
    for hasColors in [false, true] {
      // given: a layer with existing attributes and optional colors
      let contentView = ComposeView()
      let layer = CALayer()
      layer.backgroundColor = hasColors ? Color.red.cgColor : nil
      layer.opacity = 0.25
      layer.borderColor = hasColors ? Color.green.cgColor : nil
      layer.borderWidth = 2
      layer.cornerRadius = 10
      layer.cornerCurve = .continuous
      let item = try firstRenderableItem(
        of: LayerNode()
          .backgroundColor(.blue)
          .opacity(0.75)
          .border(color: .yellow, width: 6)
          .cornerRadius(20, cornerCurve: .circular)
      ).unwrap()

      // when: a refresh applies new attributes with animation
      item.update(.layer(layer), RenderableUpdateContext(
        updateType: .refresh,
        oldFrame: item.frame,
        newFrame: item.frame,
        previousRenderBounds: .zero,
        renderBounds: .zero,
        animationTiming: .easeInEaseOut(duration: 1),
        contentView: contentView,
        contentEvaluation: nil,
        animationDecision: ComposeView.AnimationDecision.all
      ))

      // then: the model layer has the newly supplied attributes
      expect(layer.backgroundColor) == Color.blue.cgColor
      expect(layer.opacity) == 0.75
      expect(layer.borderColor) == Color.yellow.cgColor
      expect(layer.borderWidth) == 6
      expect(layer.cornerRadius) == 20
      expect(layer.cornerCurve) == .circular

      // then: color animations use the previous color or a clear fallback
      let backgroundAnimation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
      expect(backgroundAnimation.fromValue as! CGColor) == (hasColors ? Color.red.cgColor : Color.clear.cgColor) // swiftlint:disable:this force_cast
      expect(backgroundAnimation.toValue as! CGColor) == Color.blue.cgColor // swiftlint:disable:this force_cast
      expect(backgroundAnimation.isAdditive) == false
      let borderColorAnimation = try (layer.animation(forKey: "borderColor") as? CABasicAnimation).unwrap()
      expect(borderColorAnimation.fromValue as! CGColor) == (hasColors ? Color.green.cgColor : Color.clear.cgColor) // swiftlint:disable:this force_cast
      expect(borderColorAnimation.toValue as! CGColor) == Color.yellow.cgColor // swiftlint:disable:this force_cast
      expect(borderColorAnimation.isAdditive) == false

      // then: scalar animations preserve their additive deltas
      let opacityAnimation = try (layer.animation(forKey: "opacity") as? CABasicAnimation).unwrap()
      expect(opacityAnimation.fromValue as? Float) == -0.5
      expect(opacityAnimation.toValue as? Float) == 0
      expect(opacityAnimation.isAdditive) == true
      let borderWidthAnimation = try (layer.animation(forKey: "borderWidth") as? CABasicAnimation).unwrap()
      expect(borderWidthAnimation.fromValue as? CGFloat) == -4
      expect(borderWidthAnimation.toValue as? CGFloat) == 0
      expect(borderWidthAnimation.isAdditive) == true
      let cornerRadiusAnimation = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
      expect(cornerRadiusAnimation.fromValue as? CGFloat) == -10
      expect(cornerRadiusAnimation.toValue as? CGFloat) == 0
      expect(cornerRadiusAnimation.isAdditive) == true
      for animation in [backgroundAnimation, opacityAnimation, borderColorAnimation, borderWidthAnimation, cornerRadiusAnimation] {
        expect(animation.duration) == 1
        expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
      }
    }
  }

  func test_interactive_boundsChanges_keepState() throws {
    for isEnabled in [true, false] {
      // given: a view whose interaction state differs from the modifier configuration
      let contentView = ComposeView()
      let view = View()
      #if canImport(AppKit)
      view.ignoreHitTest = !isEnabled
      #endif
      #if canImport(UIKit)
      view.isUserInteractionEnabled = isEnabled
      #endif
      let item = try firstRenderableItem(of: ViewNode().interactive(!isEnabled)).unwrap()

      let previousRenderBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      for renderBounds in [previousRenderBounds.offsetBy(dx: 0, dy: 20), CGRect(x: 0, y: 0, width: 100, height: 60)] {
        // when: the modifier receives a bounds change
        item.update(.view(view), RenderableUpdateContext(
          updateType: .boundsChange,
          oldFrame: item.frame,
          newFrame: CGRect(x: 0, y: 0, width: 100, height: 60),
          previousRenderBounds: previousRenderBounds,
          renderBounds: renderBounds,
          animationTiming: nil,
          contentView: contentView,
          contentEvaluation: nil,
          animationDecision: ComposeView.AnimationDecision.disabled
        ))

        // then: the existing interaction state is kept
        #if canImport(AppKit)
        expect(view.ignoreHitTest) == !isEnabled
        #endif
        #if canImport(UIKit)
        expect(view.isUserInteractionEnabled) == isEnabled
        #endif
      }

      // when: the same item receives an explicit refresh
      item.update(.view(view), RenderableUpdateContext(
        updateType: .refresh,
        oldFrame: item.frame,
        newFrame: item.frame,
        previousRenderBounds: .zero,
        renderBounds: .zero,
        animationTiming: nil,
        contentView: contentView,
        contentEvaluation: nil,
        animationDecision: ComposeView.AnimationDecision.disabled
      ))

      // then: refresh applies the configured interaction state
      #if canImport(AppKit)
      expect(view.ignoreHitTest) == isEnabled
      #endif
      #if canImport(UIKit)
      expect(view.isUserInteractionEnabled) == !isEnabled
      #endif
    }
  }

  func test_interactive_nonView_preservesLayer() throws {
    for isEnabled in [true, false] {
      // given: an interactive modifier applied to a non-view renderable
      let contentView = ComposeView()
      let layer = CALayer()
      layer.opacity = 0.5
      layer.backgroundColor = Color.red.cgColor
      let item = try firstRenderableItem(of: LayerNode().interactive(isEnabled)).unwrap()

      let previousRenderBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let scenarios: [(RenderableUpdateType, CGRect)] = [
        (.insert, previousRenderBounds),
        (.refresh, previousRenderBounds),
        (.boundsChange, previousRenderBounds.offsetBy(dx: 0, dy: 20)),
        (.boundsChange, CGRect(x: 0, y: 0, width: 100, height: 60)),
      ]
      for (updateType, renderBounds) in scenarios {
        // when: the modifier receives an update for the layer
        item.update(.layer(layer), RenderableUpdateContext(
          updateType: updateType,
          oldFrame: item.frame,
          newFrame: item.frame,
          previousRenderBounds: previousRenderBounds,
          renderBounds: renderBounds,
          animationTiming: nil,
          contentView: contentView,
          contentEvaluation: nil,
          animationDecision: ComposeView.AnimationDecision.disabled
        ))

        // then: the non-view renderable keeps its properties
        expect(layer.opacity) == 0.5
        expect(layer.backgroundColor) == Color.red.cgColor
      }

      // when: the modifier resets the non-view renderable for reuse
      item.resetForReuse?(.layer(layer))

      // then: the layer properties are unchanged
      expect(layer.opacity) == 0.5
      expect(layer.backgroundColor) == Color.red.cgColor
    }
  }

  // MARK: - Reset for reuse

  func test_layerModifiers_resetForReuse_resetsModifiedProperties() {
    // each built-in layer modifier registers a `resetForReuse` block that resets the property it set back to the
    // value a freshly made layer would have, so a recycled layer never leaks state into a differently-configured reuse.

    // backgroundColor
    do {
      // given: a layer with a background color set
      let layer = CALayer()
      layer.backgroundColor = Color.red.cgColor

      // when: the reset for reuse block runs
      firstRenderableItem(of: LayerNode().backgroundColor(.red))?.resetForReuse?(.layer(layer))

      // then: the background color is reset
      expect(layer.backgroundColor) == nil
    }

    // opacity
    do {
      // given: a layer with an opacity set
      let layer = CALayer()
      layer.opacity = 0.3

      // when: the reset for reuse block runs
      firstRenderableItem(of: LayerNode().opacity(0.3))?.resetForReuse?(.layer(layer))

      // then: the opacity is reset
      expect(layer.opacity) == 1
    }

    // border
    do {
      // given: a layer with a border set
      let layer = CALayer()
      layer.borderColor = Color.red.cgColor
      layer.borderWidth = 4

      // when: the reset for reuse block runs
      firstRenderableItem(of: LayerNode().border(color: .red, width: 4))?.resetForReuse?(.layer(layer))

      // then: the border is reset
      expect(layer.borderColor) == CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
      expect(layer.borderWidth) == 0
    }

    // cornerRadius
    do {
      // given: a layer with a corner radius set
      let layer = CALayer()
      layer.cornerRadius = 10
      layer.cornerCurve = .circular

      // when: the reset for reuse block runs
      firstRenderableItem(of: LayerNode().cornerRadius(10))?.resetForReuse?(.layer(layer))

      // then: the corner radius and corner curve are reset
      expect(layer.cornerRadius) == 0
      expect(layer.cornerCurve) == .continuous
    }

    // masksToBounds
    do {
      // given: a layer with masksToBounds set
      let layer = CALayer()
      layer.masksToBounds = true

      // when: the reset for reuse block runs
      firstRenderableItem(of: LayerNode().masksToBounds(true))?.resetForReuse?(.layer(layer))

      // then: masksToBounds is reset
      expect(layer.masksToBounds) == false
    }

    // shadow
    do {
      // given: a layer with a shadow set
      let layer = CALayer()
      layer.shadowColor = Color.red.cgColor
      layer.shadowOpacity = 0.8
      layer.shadowRadius = 12
      layer.shadowOffset = CGSize(width: 5, height: 5)
      layer.shadowPath = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil)

      // when: the reset for reuse block runs
      firstRenderableItem(of: LayerNode().shadow(color: .red, opacity: 0.8, radius: 12, offset: CGSize(width: 5, height: 5), path: nil))?
        .resetForReuse?(.layer(layer))

      // then: the shadow is reset
      expect(layer.shadowOpacity) == 0
      expect(layer.shadowColor) == CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
      expect(layer.shadowRadius) == 3
      expect(layer.shadowOffset) == CGSize(width: 0, height: -3)
      expect(layer.shadowPath) == nil
    }

    // zIndex: the modifier sets the item's z-index attribute instead of modifying the layer, so it adds no
    // `resetForReuse`. the render pass owns the layer's `zPosition` and resets it when the renderable is pooled
    // (see `ComposeView_RenderReuseTests.test_pooledRenderable_zPositionIsReset`).
    do {
      // given: a renderable item from a node with a z-index
      let item = firstRenderableItem(of: LayerNode().zIndex(7))

      // then: the item has the z-index attribute and no reset block
      expect(item?.zIndex) == 7
      expect(item?.resetForReuse) == nil
    }

    // interactive
    do {
      // given: a view with interaction disabled
      let view = View()
      #if canImport(AppKit)
      view.ignoreHitTest = true
      #endif
      #if canImport(UIKit)
      view.isUserInteractionEnabled = false
      #endif

      // when: the reset for reuse block runs
      firstRenderableItem(of: ViewNode().interactive(true))?.resetForReuse?(.view(view))

      // then: the interaction state is reset
      #if canImport(AppKit)
      expect(view.ignoreHitTest) == false
      #endif
      #if canImport(UIKit)
      expect(view.isUserInteractionEnabled) == true
      #endif
    }

    // rasterize
    do {
      // given: a layer with rasterization set
      let layer = CALayer()
      layer.shouldRasterize = true
      layer.rasterizationScale = 3

      // when: the reset for reuse block runs
      firstRenderableItem(of: LayerNode().rasterize(3))?.resetForReuse?(.layer(layer))

      // then: the rasterization is reset
      expect(layer.shouldRasterize) == false
      expect(layer.rasterizationScale) == 1
    }
  }

  // MARK: - Animated and Non-animated Updates

  func test_layerModifiers_animatedUpdate_animatesOnlyTheChangedValue() throws {
    let baseItem = try styledItem()
    let changedItems: [(keyPath: String, item: RenderableItem)] = try [
      ("backgroundColor", styledItem(backgroundColor: .yellow)),
      ("opacity", styledItem(opacity: 0.8)),
      ("borderColor", styledItem(borderColor: .yellow)),
      ("borderWidth", styledItem(borderWidth: 5)),
      ("cornerRadius", styledItem(cornerRadius: 8)),
      ("shadowColor", styledItem(shadowColor: .yellow)),
      ("shadowOpacity", styledItem(shadowOpacity: 0.9)),
      ("shadowRadius", styledItem(shadowRadius: 6)),
      ("shadowOffset", styledItem(shadowOffset: CGSize(width: 3, height: 4))),
      ("shadowPath", styledItem(shadowPathInset: 2)),
    ]
    for (keyPath, changedItem) in changedItems {
      // given: a layer styled by every layer modifier without animation
      let layer = CALayer()
      layer.frame = baseItem.frame
      refresh(.layer(layer), with: baseItem, animationTiming: nil)

      // when: refreshing with animation and nothing changed
      refresh(.layer(layer), with: baseItem, animationTiming: .easeInEaseOut(duration: 1))

      // then: nothing animates
      expect(layer.animationKeys(), keyPath) == nil

      // when: refreshing with animation and one value changed
      refresh(.layer(layer), with: changedItem, animationTiming: .easeInEaseOut(duration: 1))

      // then: only that value animates
      expect(layer.animationKeys(), keyPath) == [keyPath]
      let animation = try layer.animation(forKey: keyPath).unwrap()

      // when: refreshing with animation again while the change animates, nothing changed
      refresh(.layer(layer), with: changedItem, animationTiming: .easeInEaseOut(duration: 2))

      // then: the in-flight animation is kept, instead of being replaced or joined by one that changes nothing
      expect(layer.animationKeys(), keyPath) == [keyPath]
      expect(layer.animation(forKey: keyPath), keyPath) === animation
    }
  }

  func test_opacity_resetForReuse_resetsTheBackingViewAlpha() throws {
    // given: a view-backed renderable whose opacity modifier animated to 0.3, which sets the layer's opacity and the
    // view's alpha
    let view = BaseView()
    let renderable = Renderable.view(view)
    let item = try firstRenderableItem(of: ViewNode(view).opacity(0.3)).unwrap()
    refresh(renderable, with: item, animationTiming: .easeInEaseOut(duration: 1))
    expect(view.alpha).to(beApproximatelyEqual(to: 0.3, within: 1e-6))

    // when: the reset for reuse block runs
    item.resetForReuse?(renderable)

    // then: the view's alpha is back to 1 along with the layer's opacity, so a reuse without the modifier isn't faded
    expect(view.alpha) == 1
    expect(renderable.layer.opacity) == 1
  }

  func test_opacity_nonAnimatedUpdate_keepsTheBackingViewAlphaInSync() throws {
    // given: a view-backed renderable whose opacity modifier animated to 0.3, which sets the layer's opacity and the
    // view's alpha
    let view = BaseView()
    let renderable = Renderable.view(view)
    try refresh(renderable, with: firstRenderableItem(of: ViewNode(view).opacity(0.3)).unwrap(), animationTiming: .easeInEaseOut(duration: 1))
    expect(view.alpha).to(beApproximatelyEqual(to: 0.3, within: 1e-6))

    // when: a non-animated update sets the opacity back to 1
    let item = try firstRenderableItem(of: ViewNode(view).opacity(1)).unwrap()
    refresh(renderable, with: item, animationTiming: nil)

    // then: the view's alpha follows the layer's opacity
    expect(renderable.layer.opacity) == 1
    expect(view.alpha) == 1

    // when: the reset for reuse block runs, with the layer's opacity already at 1
    item.resetForReuse?(renderable)

    // then: the view isn't left faded
    expect(view.alpha) == 1
  }

  // MARK: - Stacked Modifiers

  func test_stackedModifiers_applyOnlyTheOutermost() throws {
    // each case stacks two modifiers of one property with an `onUpdate` block between them, which checks whether the
    // property still has its default value where the inner modifier would have set it
    struct Case {
      let name: String
      let renderable: Renderable
      let node: (_ checkBetween: @escaping (Renderable) -> Void) -> any ComposeNode
      let hasDefaultValue: (Renderable) -> Bool
      let hasOuterValue: (Renderable) -> Bool
    }

    let view = BaseView()
    let cases: [Case] = [
      Case(
        name: "backgroundColor",
        renderable: .layer(CALayer()),
        node: { checkBetween in
          LayerNode().backgroundColor(.red).onUpdate { renderable, _ in checkBetween(renderable) }.backgroundColor(.blue)
        },
        hasDefaultValue: { $0.layer.backgroundColor == nil },
        hasOuterValue: { $0.layer.backgroundColor == Color.blue.cgColor }
      ),
      Case(
        name: "opacity",
        renderable: .layer(CALayer()),
        node: { checkBetween in
          LayerNode().opacity(0.3).onUpdate { renderable, _ in checkBetween(renderable) }.opacity(0.6)
        },
        hasDefaultValue: { $0.layer.opacity == 1 },
        hasOuterValue: { $0.layer.opacity == 0.6 }
      ),
      Case(
        name: "border",
        renderable: .layer(CALayer()),
        node: { checkBetween in
          LayerNode().border(color: .red, width: 1).onUpdate { renderable, _ in checkBetween(renderable) }.border(color: .blue, width: 2)
        },
        hasDefaultValue: { $0.layer.borderWidth == 0 },
        hasOuterValue: { $0.layer.borderWidth == 2 && $0.layer.borderColor == Color.blue.cgColor }
      ),
      Case(
        name: "cornerRadius",
        renderable: .layer(CALayer()),
        node: { checkBetween in
          LayerNode().cornerRadius(4).onUpdate { renderable, _ in checkBetween(renderable) }.cornerRadius(8)
        },
        hasDefaultValue: { $0.layer.cornerRadius == 0 },
        hasOuterValue: { $0.layer.cornerRadius == 8 }
      ),
      Case(
        name: "masksToBounds",
        renderable: .layer(CALayer()),
        node: { checkBetween in
          LayerNode().masksToBounds(true).onUpdate { renderable, _ in checkBetween(renderable) }.masksToBounds(true)
        },
        hasDefaultValue: { !$0.layer.masksToBounds },
        hasOuterValue: { $0.layer.masksToBounds }
      ),
      Case(
        name: "shadow",
        renderable: .layer(CALayer()),
        node: { checkBetween in
          LayerNode()
            .shadow(color: .red, opacity: 0.3, radius: 2, offset: CGSize(width: 1, height: 1), path: nil)
            .onUpdate { renderable, _ in checkBetween(renderable) }
            .shadow(color: .blue, opacity: 0.6, radius: 4, offset: CGSize(width: 2, height: 2), path: nil)
        },
        hasDefaultValue: { $0.layer.shadowOpacity == 0 },
        hasOuterValue: { $0.layer.shadowOpacity == 0.6 && $0.layer.shadowRadius == 4 && $0.layer.shadowColor == Color.blue.cgColor }
      ),
      Case(
        name: "interactive",
        renderable: .view(view),
        node: { checkBetween in
          ViewNode(view).interactive(false).onUpdate { renderable, _ in checkBetween(renderable) }.interactive(false)
        },
        hasDefaultValue: { $0.isInteractive },
        hasOuterValue: { !$0.isInteractive }
      ),
      Case(
        name: "rasterize",
        renderable: .layer(CALayer()),
        node: { checkBetween in
          LayerNode().rasterize(2).onUpdate { renderable, _ in checkBetween(renderable) }.rasterize(3)
        },
        hasDefaultValue: { !$0.layer.shouldRasterize },
        hasOuterValue: { $0.layer.shouldRasterize && $0.layer.rasterizationScale == 3 }
      ),
    ]

    for testCase in cases {
      // given: the stacked modifiers' renderable item
      var hasDefaultValueBetween: Bool?
      let item = try firstRenderableItem(of: testCase.node { hasDefaultValueBetween = testCase.hasDefaultValue($0) }).unwrap()

      // when: a non-animated update
      refresh(testCase.renderable, with: item, animationTiming: nil)

      // then: the inner modifier doesn't apply its value, and the outer one does
      expect(hasDefaultValueBetween, testCase.name) == true
      expect(testCase.hasOuterValue(testCase.renderable), testCase.name) == true

      // when: an animated update with the same values
      refresh(testCase.renderable, with: item, animationTiming: .easeInEaseOut(duration: 1))

      // then: nothing animates, as the inner value never reaches the layer to animate through
      expect(testCase.renderable.layer.animationKeys(), testCase.name) == nil
    }
  }

  func test_stackedModifiers_splitByANode_applyOnlyTheOutermost() throws {
    // given: two opacity modifiers split by a padding node, which the modifiers don't coalesce across, with an
    // `onUpdate` block after the inner one
    var opacityBetween: Float?
    let renderable = Renderable.layer(CALayer())
    let item = try firstRenderableItem(
      of: LayerNode()
        .opacity(0.3)
        .onUpdate { renderable, _ in opacityBetween = renderable.layer.opacity }
        .padding(4)
        .opacity(0.6)
    ).unwrap()

    // when: a non-animated update
    refresh(renderable, with: item, animationTiming: nil)

    // then: the inner modifier doesn't apply its value, and the outer one does
    expect(opacityBetween) == 1
    expect(renderable.layer.opacity) == 0.6

    // when: an animated update with the same value
    refresh(renderable, with: item, animationTiming: .easeInEaseOut(duration: 1))

    // then: nothing animates
    expect(renderable.layer.animationKeys()) == nil
  }

  func test_stackedOpacity_animatedRefresh_doesNotAnimateThroughTheInnerValue() {
    // given: a rendered layer node with two opacity modifiers and an animation
    var layer: CALayer?
    let contentView = ComposeView {
      LayerNode()
        .opacity(0.3)
        .opacity(1)
        .animation(.easeInEaseOut(duration: 1))
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    // when: an animated refresh with the same values
    contentView.refresh(animated: true)

    // then: the layer shows the outer opacity without animating, where it used to add opposing opacity animations
    // that the render server showed as a dip to the inner value
    expect(layer?.opacity) == 1
    expect(layer?.animationKeys()) == nil
  }

  // MARK: - Helpers

  /// The renderable item of a layer node with every layer modifier, with the given values.
  private func styledItem(backgroundColor: Color = .red,
                          opacity: CGFloat = 0.5,
                          borderColor: Color = .green,
                          borderWidth: CGFloat = 2,
                          cornerRadius: CGFloat = 4,
                          shadowColor: Color = .blue,
                          shadowOpacity: CGFloat = 0.3,
                          shadowRadius: CGFloat = 3,
                          shadowOffset: CGSize = CGSize(width: 1, height: 2),
                          shadowPathInset: CGFloat = 0) throws -> RenderableItem
  {
    try firstRenderableItem(
      of: LayerNode()
        .backgroundColor(backgroundColor)
        .opacity(opacity)
        .border(color: borderColor, width: borderWidth)
        .cornerRadius(cornerRadius)
        .shadow(color: shadowColor, opacity: shadowOpacity, radius: shadowRadius, offset: shadowOffset, path: { renderable in
          CGPath(rect: renderable.layer.bounds.insetBy(dx: shadowPathInset, dy: shadowPathInset), transform: nil)
        })
    ).unwrap()
  }

  /// Updates the renderable with the item for a refresh with the animation timing.
  private func refresh(_ renderable: Renderable, with item: RenderableItem, animationTiming: AnimationTiming?) {
    // the context holds the content view weakly, so the view is kept alive through the update
    let contentView = ComposeView()
    withExtendedLifetime(contentView) {
      item.update(renderable, RenderableUpdateContext(
        updateType: .refresh,
        oldFrame: item.frame,
        newFrame: item.frame,
        previousRenderBounds: .zero,
        renderBounds: .zero,
        animationTiming: animationTiming,
        contentView: contentView,
        contentEvaluation: nil,
        animationDecision: animationTiming == nil ? ComposeView.AnimationDecision.disabled : ComposeView.AnimationDecision.all
      ))
    }
  }

  private func firstRenderableItem(of node: some ComposeNode) -> RenderableItem? {
    var node = node
    let size = CGSize(width: 100, height: 50)
    _ = node.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: 2))
    return node.renderableItems(in: CGRect(origin: .zero, size: size)).first
  }
}

private extension Renderable {

  /// Whether the renderable's view takes user interaction, as the `interactive` modifier sets it.
  var isInteractive: Bool {
    #if canImport(AppKit)
    return view?.ignoreHitTest != true
    #endif

    #if canImport(UIKit)
    return view?.isUserInteractionEnabled != false
    #endif
  }
}
