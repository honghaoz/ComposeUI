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

  // MARK: - Animation and Transition Priority

  func test_animationAndTransitionPriority() {
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
  }
}
