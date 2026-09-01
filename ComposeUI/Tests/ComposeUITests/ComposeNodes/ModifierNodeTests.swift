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

import ComposeUI

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
      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(.red)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated twice
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      // then: the layer has the background color with an animation
      expect(layer?.backgroundColor) == Color.red.cgColor
      expect(layer?.animationKeys()?.contains("backgroundColor")) == true
    }

    // early return when requiresFullUpdate is false
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

      // then: the bounds change should not set the new color
      expect(layer?.backgroundColor) == Color.red.cgColor

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
      let contentView = ComposeView {
        LayerNode()
          .opacity(0.6)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated twice
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      // then: the layer has the opacity with an animation
      expect(layer?.opacity) == 0.6
      expect(layer?.animationKeys()?.contains("opacity")) == true
    }

    // early return when requiresFullUpdate is false
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

      // then: the bounds change should not set the new opacity
      expect(layer?.opacity) == 0.5

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
      let contentView = ComposeView {
        LayerNode()
          .border(color: .cyan, width: 4)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated twice
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      // then: the layer has the border with animations
      expect(layer?.borderColor) == Color.cyan.cgColor
      expect(layer?.borderWidth) == 4
      expect(layer?.animationKeys()?.contains("borderColor")) == true
      expect(layer?.animationKeys()?.contains("borderWidth")) == true
    }

    // early return when requiresFullUpdate is false
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

      // then: the bounds change should not set the new border
      expect(layer?.borderColor) == Color.red.cgColor
      expect(layer?.borderWidth) == 2

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
      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(15)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated twice
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      // then: the layer has the corner radius with an animation
      expect(layer?.cornerRadius) == 15
      expect(layer?.animationKeys()?.contains("cornerRadius")) == true
    }

    // early return when requiresFullUpdate is false
    do {
      // given: a layer node with a captured corner radius
      var layer: CALayer?
      var cornerRadius: CGFloat = 10

      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(cornerRadius)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      // then: the layer has the initial corner radius
      expect(layer?.cornerRadius) == 10

      // when: the bounds change with a new corner radius set
      cornerRadius = 20
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      // then: the bounds change should not set the new corner radius
      expect(layer?.cornerRadius) == 10

      // when: the view is refreshed with a new corner radius set
      cornerRadius = 8
      contentView.refresh()

      // then: the refresh should set the new corner radius
      expect(layer?.cornerRadius) == 8
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

    // early return when requiresFullUpdate is false
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

      // then: the bounds change should not set the new masksToBounds
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
      let contentView = ComposeView {
        LayerNode()
          .shadow(color: .orange, opacity: 0.5, radius: 6, offset: CGSize(width: 3, height: 3), path: nil)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      // when: the view is sized and refreshed animated twice
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      // then: the layer has the shadow with animations
      expect(layer?.shadowColor) == Color.orange.cgColor
      expect(layer?.shadowOpacity) == 0.5
      expect(layer?.shadowRadius) == 6
      expect(layer?.shadowOffset) == CGSize(width: 3, height: 3)
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
          .shadow(color: shadowColor, opacity: shadowOpacity, radius: shadowRadius, offset: shadowOffset, path: nil)
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

      // then: the bounds change should set the new shadow
      expect(layer?.shadowColor) == Color.blue.cgColor
      expect(layer?.shadowOpacity) == 0.8
      expect(layer?.shadowRadius) == 8
      expect(layer?.shadowOffset) == CGSize(width: 5, height: 5)

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

      // then: the bounds change re-evaluates the content, which picks up the new z-index
      expect(layer.map { floor($0.zPosition) }) == 10

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

    // early return when requiresFullUpdate is false
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

      // then: the bounds change should not set the new interactive state
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

    // early return when requiresFullUpdate is false
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

      // then: the bounds change should not set the new rasterize settings
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

  // MARK: - Helpers

  private func firstRenderableItem(of node: some ComposeNode) -> RenderableItem? {
    var node = node
    let size = CGSize(width: 100, height: 50)
    _ = node.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: 2))
    return node.renderableItems(in: CGRect(origin: .zero, size: size)).first
  }
}
