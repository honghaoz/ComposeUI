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
    let baseNode = ViewNode()
    let originalId = baseNode.id

    let modifierNode = baseNode.opacity(0.5)

    // initial id should match the base node
    expect(modifierNode.id) == originalId

    // setting id on modifier should affect the inner node, hence the renderable items
    let newId = ComposeNodeId.custom("new")
    var mutableModifierNode = modifierNode
    mutableModifierNode.id = newId

    expect(mutableModifierNode.id) == newId

    let containerSize = CGSize(width: 100, height: 50)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    mutableModifierNode.layout(containerSize: containerSize, context: context)
    let renderableItems = mutableModifierNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))
    expect(renderableItems.first?.id) == newId
  }

  func test_size() {
    // test that size property delegates to underlying node

    // initial size should be zero
    do {
      let baseNode = ViewNode()
      let modifierNode = baseNode.opacity(0.5)

      expect(modifierNode.size) == .zero
      expect(modifierNode.size) == baseNode.size
    }

    // modifier node with pre-layout node
    do {
      var baseNode = ViewNode()

      let containerSize = CGSize(width: 100, height: 50)
      let context = ComposeNodeLayoutContext(scaleFactor: 2)

      _ = baseNode.layout(containerSize: containerSize, context: context)

      let modifierNode = baseNode.opacity(0.5)

      expect(modifierNode.size) == containerSize
      expect(modifierNode.size) == baseNode.size
    }
  }

  // MARK: - Life cycle calls

  func test_lifeCycleCalls() {
    // given many modifiers
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

    // expect modifiers are coalescing
    expect(
      String(describing: node).hasPrefix("ModifierNode(node: ComposeUI.ViewNode<")
    ) == true

    // when the compose view is refreshed
    let composeView = ComposeView { node }
    composeView.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

    composeView.refresh(animated: false)

    // then the modifier calls are called in order
    expect(willInsertCalls) == ["first", "second"]
    expect(didInsertCalls) == ["first", "second"]
    expect(willUpdateCalls) == ["first", "second"]
    expect(updateCalls) == ["first", "second"]
    expect(willRemoveCalls) == []
    expect(didRemoveCalls) == []

    // when the content removed
    composeView.setContent { Empty() }
    composeView.refresh(animated: false)

    // then the remove modifier calls are called in order
    expect(willInsertCalls) == ["first", "second"]
    expect(didInsertCalls) == ["first", "second"]
    expect(willUpdateCalls) == ["first", "second"]
    expect(updateCalls) == ["first", "second"]
    expect(willRemoveCalls) == ["first", "second"]
    expect(didRemoveCalls) == ["first", "second"]
  }

  // MARK: - Animation

  func test_animation() {
    let expectation = expectation(description: "animation")

    // given a view node with multiple animations
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

    // when the compose view is refreshed
    let composeView = ComposeView { node }
    composeView.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

    composeView.refresh(animated: true)
    composeView.refresh(animated: true)

    wait(for: [expectation], timeout: 1)
  }

  // MARK: - Transition

  func test_transition() {
    // basic transition
    do {
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

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)

      expect(insertionCompleted) == true
      expect(removalCompleted) == false

      // remove the content to test removal transition
      contentView.setContent { Empty() }
      contentView.refresh(animated: true)

      expect(insertionCompleted) == true
      expect(removalCompleted) == true
    }

    // multiple transitions (inner one wins)
    do {
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

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)

      expect(firstTransitionUsed) == true
      expect(secondTransitionUsed) == false
    }

    // predefined opacity transition
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .transition(.opacity(from: 0, to: 1, timing: .easeInEaseOut(duration: 0.1)))
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)

      // Layer should eventually have full opacity after transition
      let expectation = expectation(description: "opacity transition")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        expect(layer?.opacity) == 1.0
        expectation.fulfill()
      }

      wait(for: [expectation], timeout: 1)
    }
  }

  // MARK: - Background Color

  func test_backgroundColor() {
    // solid color
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(.red)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.backgroundColor) == Color.red.cgColor
    }

    // themed color
    do {
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

      contentView.overrideTheme = .dark
      contentView.refresh()
      expect(layer?.backgroundColor) == Color.green.cgColor

      contentView.overrideTheme = .light
      contentView.refresh()
      expect(layer?.backgroundColor) == Color.blue.cgColor
    }

    // multiple modifiers (last one wins)
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(.red)
          .backgroundColor(.blue) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.backgroundColor) == Color.blue.cgColor
    }

    // with animation
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(.red)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      expect(layer?.backgroundColor) == Color.red.cgColor
      expect(layer?.animationKeys()?.contains("backgroundColor")) == true
    }

    // early return when requiresFullUpdate is false
    do {
      var layer: CALayer?
      var color: Color = .red

      let contentView = ComposeView {
        LayerNode()
          .backgroundColor(color)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      expect(layer?.backgroundColor) == Color.red.cgColor

      // bounds change should not set new color
      color = .blue
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.backgroundColor) == Color.red.cgColor

      // refresh should set new color
      color = .green
      contentView.refresh()

      expect(layer?.backgroundColor) == Color.green.cgColor
    }
  }

  // MARK: - Opacity

  func test_opacity() {
    // normal opacity value
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .opacity(0.5)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.opacity) == 0.5
    }

    // themed opacity
    do {
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

      contentView.overrideTheme = .light
      contentView.refresh()
      expect(layer?.opacity) == 0.8

      contentView.overrideTheme = .dark
      contentView.refresh()
      expect(layer?.opacity) == 0.3
    }

    // multiple modifiers (last one wins)
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .opacity(0.3)
          .opacity(0.7) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.opacity) == 0.7
    }

    // with animation
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .opacity(0.6)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      expect(layer?.opacity) == 0.6
      expect(layer?.animationKeys()?.contains("opacity")) == true
    }

    // early return when requiresFullUpdate is false
    do {
      var layer: CALayer?
      var opacity: CGFloat = 0.5

      let contentView = ComposeView {
        LayerNode()
          .opacity(opacity)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      expect(layer?.opacity) == 0.5

      // bounds change should not set new opacity
      opacity = 0.8
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.opacity) == 0.5

      // refresh should set new opacity
      opacity = 0.3
      contentView.refresh()

      expect(layer?.opacity) == 0.3
    }
  }

  // MARK: - Border

  func test_border() {
    // basic border
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .border(color: .red, width: 2)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.borderColor) == Color.red.cgColor
      expect(layer?.borderWidth) == 2
    }

    // themed border
    do {
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

      contentView.overrideTheme = .light
      contentView.refresh()
      expect(layer?.borderColor) == Color.green.cgColor
      expect(layer?.borderWidth) == 1

      contentView.overrideTheme = .dark
      contentView.refresh()
      expect(layer?.borderColor) == Color.orange.cgColor
      expect(layer?.borderWidth) == 3
    }

    // multiple modifiers (last one wins)
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .border(color: .red, width: 1)
          .border(color: .blue, width: 3) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.borderColor) == Color.blue.cgColor
      expect(layer?.borderWidth) == 3
    }

    // with animation
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .border(color: .cyan, width: 4)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      expect(layer?.borderColor) == Color.cyan.cgColor
      expect(layer?.borderWidth) == 4
      expect(layer?.animationKeys()?.contains("borderColor")) == true
      expect(layer?.animationKeys()?.contains("borderWidth")) == true
    }

    // early return when requiresFullUpdate is false
    do {
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

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      expect(layer?.borderColor) == Color.red.cgColor
      expect(layer?.borderWidth) == 2

      // bounds change should not set new border
      borderColor = .blue
      borderWidth = 5
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.borderColor) == Color.red.cgColor
      expect(layer?.borderWidth) == 2

      // refresh should set new border
      borderColor = .green
      borderWidth = 3
      contentView.refresh()

      expect(layer?.borderColor) == Color.green.cgColor
      expect(layer?.borderWidth) == 3
    }
  }

  // MARK: - Corner Radius

  func test_cornerRadius() {
    // default cornerCurve
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(10)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.cornerRadius) == 10
      expect(layer?.cornerCurve) == .continuous
    }

    // explicit cornerCurve
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(15, cornerCurve: .circular)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.cornerRadius) == 15
      expect(layer?.cornerCurve) == .circular
    }

    // with animation
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(15)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

      expect(layer?.cornerRadius) == 15
      expect(layer?.animationKeys()?.contains("cornerRadius")) == true
    }

    // early return when requiresFullUpdate is false
    do {
      var layer: CALayer?
      var cornerRadius: CGFloat = 10

      let contentView = ComposeView {
        LayerNode()
          .cornerRadius(cornerRadius)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      expect(layer?.cornerRadius) == 10

      // bounds change should not set new corner radius
      cornerRadius = 20
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.cornerRadius) == 10

      // refresh should set new corner radius
      cornerRadius = 8
      contentView.refresh()

      expect(layer?.cornerRadius) == 8
    }
  }

  // MARK: - Masks To Bounds

  func test_masksToBounds() {
    // default value (true)
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds()
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.masksToBounds) == true
    }

    // explicit true
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(true)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.masksToBounds) == true
    }

    // explicit false
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(false)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.masksToBounds) == false
    }

    // update from true to false
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(true)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.masksToBounds) == true

      // Update to false
      contentView.setContent {
        LayerNode()
          .masksToBounds(false)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }
      contentView.refresh()

      expect(layer?.masksToBounds) == false
    }

    // multiple modifiers (last one wins)
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(true)
          .masksToBounds(false) // This should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.masksToBounds) == false
    }

    // early return when requiresFullUpdate is false
    do {
      var layer: CALayer?
      var masksToBounds: Bool = true

      let contentView = ComposeView {
        LayerNode()
          .masksToBounds(masksToBounds)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      expect(layer?.masksToBounds) == true

      // bounds change should not set new masksToBounds
      masksToBounds = false
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.masksToBounds) == true

      // refresh should set new masksToBounds
      masksToBounds = false
      contentView.refresh()

      expect(layer?.masksToBounds) == false
    }
  }

  // MARK: - Shadow

  func test_shadow() {
    // basic shadow
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .shadow(color: .red, opacity: 0.5, radius: 4, offset: CGSize(width: 2, height: 2), path: nil)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.5
      expect(layer?.shadowRadius) == 4
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 2)
      expect(layer?.masksToBounds) == false
    }

    // themed shadow
    do {
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

      contentView.overrideTheme = .light
      contentView.refresh()
      expect(layer?.shadowColor) == Color.gray.cgColor
      expect(layer?.shadowOpacity) == 0.3
      expect(layer?.shadowRadius) == 2
      expect(layer?.shadowOffset) == CGSize(width: 1, height: 1)
      expect(layer?.shadowPath) == nil

      contentView.overrideTheme = .dark
      contentView.refresh()
      expect(layer?.shadowColor) == Color.white.cgColor
      expect(layer?.shadowOpacity) == 0.8
      expect(layer?.shadowRadius) == 6
      expect(layer?.shadowOffset) == CGSize(width: 4, height: 4)
      expect(layer?.shadowPath) == nil
    }

    // shadow with custom path
    do {
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

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.shadowColor) == Color.blue.cgColor
      expect(layer?.shadowOpacity) == 0.7
      expect(layer?.shadowRadius) == 3
      expect(layer?.shadowOffset) == .zero
      expect(layer?.shadowPath) == BezierPath(rect: CGRect(x: 0, y: 0, width: 50, height: 25)).cgPath
    }

    // multiple modifiers (last one wins)
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .shadow(color: .red, opacity: 0.1, radius: 1, offset: .zero, path: nil)
          .shadow(color: .blue, opacity: 0.6, radius: 5, offset: CGSize(width: 2, height: 3), path: nil) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.shadowColor) == Color.blue.cgColor
      expect(layer?.shadowOpacity) == 0.6
      expect(layer?.shadowRadius) == 5
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 3)
    }

    // with animation
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .shadow(color: .orange, opacity: 0.5, radius: 6, offset: CGSize(width: 3, height: 3), path: nil)
          .animation(.easeInEaseOut(duration: 1))
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh(animated: true)
      contentView.refresh(animated: true)

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

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.5
      expect(layer?.shadowRadius) == 4
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 2)

      // scroll should not set new shadow
      shadowColor = .blue
      shadowOpacity = 0.8
      shadowRadius = 8
      shadowOffset = CGSize(width: 5, height: 5)
      contentView.frame = CGRect(x: 0, y: 2, width: 100, height: 50)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.5
      expect(layer?.shadowRadius) == 4
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 2)

      // bounds change should set new shadow
      contentView.frame = CGRect(x: 0, y: 2, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.shadowColor) == Color.blue.cgColor
      expect(layer?.shadowOpacity) == 0.8
      expect(layer?.shadowRadius) == 8
      expect(layer?.shadowOffset) == CGSize(width: 5, height: 5)

      // refresh should set new shadow
      shadowColor = .red
      shadowOpacity = 0.4
      shadowRadius = 7
      shadowOffset = CGSize(width: 2, height: 3)
      contentView.refresh()

      expect(layer?.shadowColor) == Color.red.cgColor
      expect(layer?.shadowOpacity) == 0.4
      expect(layer?.shadowRadius) == 7
      expect(layer?.shadowOffset) == CGSize(width: 2, height: 3)
    }
  }

  // MARK: - Z-Index

  func test_zIndex() {
    // positive z index
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .zIndex(5)
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.zPosition) == 5
    }

    // multiple modifiers (last one wins)
    do {
      var layer: CALayer?
      let contentView = ComposeView {
        LayerNode()
          .zIndex(2)
          .zIndex(8) // this should win
          .onInsert { renderable, _ in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      expect(layer?.zPosition) == 8
    }

    // early return when requiresFullUpdate is false
    do {
      var layer: CALayer?
      var zIndex: CGFloat = 5

      let contentView = ComposeView {
        LayerNode()
          .zIndex(zIndex)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      expect(layer?.zPosition) == 5

      // bounds change should not set new z index
      zIndex = 10
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.zPosition) == 5

      // refresh should set new z index
      zIndex = 3
      contentView.refresh()

      expect(layer?.zPosition) == 3
    }
  }

  // MARK: - Interactive

  func test_interactive() {
    do {
      var view: View?
      let contentView = ComposeView {
        ViewNode()
          .interactive()
          .onInsert { renderable, _ in
            view = renderable.view
          }
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == false
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == true
      #endif
    }

    do {
      var view: View?
      let contentView = ComposeView {
        ViewNode()
          .interactive(false)
          .onInsert { renderable, _ in
            view = renderable.view
          }
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh()

      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == true
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == false
      #endif
    }

    // early return when requiresFullUpdate is false
    do {
      var view: View?
      var isInteractive: Bool = true

      let contentView = ComposeView {
        ViewNode()
          .interactive(isInteractive)
          .onUpdate { renderable, context in
            view = renderable.view
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == false
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == true
      #endif

      // bounds change should not set new interactive state
      isInteractive = false
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      #if canImport(AppKit)
      expect(view?.ignoreHitTest) == false
      #endif

      #if canImport(UIKit)
      expect(view?.isUserInteractionEnabled) == true
      #endif

      // refresh should set new interactive state
      isInteractive = false
      contentView.refresh()

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
    var layer: CALayer?
    let contentView = ComposeView {
      LayerNode()
        .rasterize(nil)
        .onInsert { renderable, _ in
          layer = renderable.layer
        }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    expect(layer?.shouldRasterize) == false
    expect(layer?.rasterizationScale) == 1

    contentView.setContent {
      LayerNode()
        .rasterize(3)
        .onInsert { renderable, _ in
          layer = renderable.layer
        }
    }
    contentView.refresh()

    expect(layer?.shouldRasterize) == true
    expect(layer?.rasterizationScale) == 3

    // early return when requiresFullUpdate is false
    do {
      var layer: CALayer?
      var rasterizeScale: CGFloat? = 2

      let contentView = ComposeView {
        LayerNode()
          .rasterize(rasterizeScale)
          .onUpdate { renderable, context in
            layer = renderable.layer
          }
      }

      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
      contentView.refresh() // initial refresh

      expect(layer?.shouldRasterize) == true
      expect(layer?.rasterizationScale) == 2

      // bounds change should not set new rasterize settings
      rasterizeScale = nil
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()

      expect(layer?.shouldRasterize) == true
      expect(layer?.rasterizationScale) == 2

      // refresh should set new rasterize settings
      rasterizeScale = nil
      contentView.refresh()

      expect(layer?.shouldRasterize) == false
      expect(layer?.rasterizationScale) == 1
    }
  }
}
