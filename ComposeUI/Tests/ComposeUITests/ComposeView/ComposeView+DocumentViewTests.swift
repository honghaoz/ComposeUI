//
//  ComposeView+DocumentViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/26.
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

#if canImport(AppKit)
import AppKit

import ChouTiTest

@testable import ComposeUI

/// Tests for the view that holds a compose view's renderables, which tells assistive technologies its children in the
/// items order, and takes the keyboard focus for the compose view.
///
/// The rows are 50 points tall in a view of 300 points, so 6 rows show, and a scroll by one row reuses the label view of
/// the row that moves out for the row that moves in, where the label view is among the subviews.
class ComposeView_DocumentViewTests: XCTestCase {

  func test_documentView() {
    // then: a compose view holds its content in a document view of its own, and both views hold it in a document view
    // that takes the keyboard focus
    expect(ComposeView(frame: .zero).documentView is ComposeView.DocumentView) == true
    expect(ComposeView(frame: .zero).documentView is ScrollDocumentView) == true
    expect(ScrollView(frame: .zero).documentView is ComposeView.DocumentView) == false
    expect(ScrollView(frame: .zero).documentView is ScrollDocumentView) == true
  }

  // MARK: - Keyboard

  func test_arrowKeys_afterAClickOnARow_scrollAndRenderTheRowsScrolledTo() throws {
    // given: rows of labels in a window, with a row clicked, which focuses the content
    let (window, view) = makeLabelRowsView()
    view.refresh(animated: false)
    window.click(at: view.convert(CGPoint(x: 50, y: 75), to: nil))
    expect(window.firstResponder) === view.contentContainerView

    // when: pressing the down arrow twice
    window.press(.down)
    window.press(.down)

    // then: the view scrolls down by 80 points, and renders the rows that show there
    expect(view.contentOffset) == CGPoint(x: 0, y: 80)
    expect(view.test.lastRenderBounds?.origin) == CGPoint(x: 0, y: 80)
    expect(rowsInSubviewOrder(of: view).sorted()) == Array(1 ..< 8)
  }

  func test_focusedTextRemovedByAScroll_keysKeepScrolling() throws {
    // given: rows in a window, with a selectable text in the first row, which has the focus
    let window = TestWindow()
    let view = ComposeView {
      VStack {
        TextNode("A selectable text")
          .frame(width: .flexible, height: Constants.rowHeight)
        for row in 1 ..< Constants.rowCount {
          LabelNode("Row \(row)")
            .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    let textView = try unwrap(view.contentContainerView.subviews.compactMap { $0 as? BaseTextView }.first)
    window.makeFirstResponder(textView)

    // when: pressing the page down key, which scrolls the text out of view
    window.press(.pageDown)

    // then: the render pass removes the text view, and the content keeps the focus, instead of the window
    expect(view.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 260)))
    expect(textView.window) == nil
    expect(window.firstResponder) === view.contentContainerView

    // when: pressing the down arrow
    window.press(.down)

    // then: the view still scrolls
    expect(view.contentOffset) == CGPoint(x: 0, y: 300)
  }

  func test_arrowKeys_inTextOfANestedViewThatFits_scrollTheViewAroundIt() throws {
    // given: rows in a window, with a nested compose view that fits a selectable text in the first row, with the focus in
    // the text
    let window = TestWindow()
    let view = ComposeView {
      VStack {
        ComposeViewNode {
          TextNode("A selectable text in a nested view")
            .frame(width: 100, height: Constants.rowHeight)
        }
        for row in 1 ..< Constants.rowCount {
          LabelNode("Row \(row)")
            .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    let nestedView = try unwrap(view.contentContainerView.subviews.compactMap { $0 as? ComposeView }.first)
    let textView = try unwrap(nestedView.contentContainerView.subviews.compactMap { $0 as? BaseTextView }.first)
    window.makeFirstResponder(textView)
    expect(nestedView.canScrollWithKeyboard) == false

    // when: pressing the down arrow
    window.press(.down)

    // then: the nested view can't scroll, so the view around it scrolls down by a line
    expect(nestedView.contentOffset) == .zero
    expect(view.contentOffset) == CGPoint(x: 0, y: 40)
  }

  func test_accessibilityChildren_ofLabelsOutOfTheItemsOrder_comeInTheItemsOrder() {
    // given: rows of labels in a window, scrolled by 2 rows, so that the label views of the rows that moved in are where
    // the rows that moved out were among the subviews
    let (_, view) = makeLabelRowsView()
    view.refresh(animated: false)
    scroll(view, to: Constants.rowHeight)
    scroll(view, to: 2 * Constants.rowHeight)
    expect(rowsInSubviewOrder(of: view)) != Array(2 ..< 8)

    // then: the compose view and its document view tell their children in the rows' order
    expect(rows(of: view.accessibilityChildren())) == Array(2 ..< 8)
    expect(rows(of: view.contentContainerView.accessibilityChildren())) == Array(2 ..< 8)
  }

  func test_accessibilityChildren_ofLabelsAmongLayers_comeInTheItemsOrder() {
    // given: rows that alternate between labels and colors, which show in layers, in a window, scrolled by 2 rows, so
    // that the label views of the rows that moved in are where the rows that moved out were among the subviews
    let window = TestWindow()
    let view = ComposeView {
      VStack {
        for row in 0 ..< Constants.rowCount {
          if row.isMultiple(of: 2) {
            LabelNode("Row \(row)")
              .frame(width: .flexible, height: Constants.rowHeight)
          } else {
            ColorNode(.red)
              .frame(width: .flexible, height: Constants.rowHeight)
          }
        }
      }
    }
    view.renderablePool = RenderablePool()
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    scroll(view, to: 2 * Constants.rowHeight)
    scroll(view, to: 4 * Constants.rowHeight)
    expect(rowsInSubviewOrder(of: view)) != [4, 6, 8]

    // then: the children are the labels, in the rows' order
    expect(rows(of: view.contentContainerView.accessibilityChildren())) == [4, 6, 8]
  }

  func test_accessibilityChildren_skipTheHiddenLabels() {
    // given: rows of labels in a window, scrolled by half a row, so that 7 rows show, and then by another half row, which
    // leaves the label view of row 0 hidden among the subviews
    let (_, view) = makeLabelRowsView()
    view.refresh(animated: false)
    scroll(view, to: Constants.rowHeight / 2)
    scroll(view, to: Constants.rowHeight)
    expect(labelViews(in: view).filter(\.isHidden).count) == 1

    // then: the children are the shown labels, in the rows' order
    expect(rows(of: view.contentContainerView.accessibilityChildren())) == Array(1 ..< 7)
  }

  func test_accessibilityChildren_inTheItemsOrderAlready_areTheUnignoredSubviews() throws {
    // given: rows of labels in a window, rendered at the top, so that the label views are in the rows' order
    let (_, view) = makeLabelRowsView()
    view.refresh(animated: false)
    expect(rowsInSubviewOrder(of: view)) == Array(0 ..< 6)

    // then: the children are the unignored subviews, as AppKit tells them
    let children = try view.contentContainerView.accessibilityChildren().unwrap()
    let unignoredSubviews = NSAccessibility.unignoredChildren(from: view.contentContainerView.subviews)
    expect(children.count) == unignoredSubviews.count
    for (child, subview) in zip(children, unignoredSubviews) {
      expect(child as AnyObject) === subview as AnyObject
    }
  }

  func test_accessibilityChildren_viewThatIsNotAnItem_keepsItsPlace() throws {
    // given: rows of labels in a window, scrolled by one row, and a view of the app's own, which no item shows, put
    // second among the content view's subviews
    let (_, view) = makeLabelRowsView()
    view.refresh(animated: false)
    scroll(view, to: Constants.rowHeight)
    let appView = AccessibleView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    let secondSubview = try view.contentContainerView.subviews.dropFirst().first.unwrap()
    view.contentContainerView.addSubview(appView, positioned: .below, relativeTo: secondSubview)

    // then: the app's view keeps its place among the children, and the labels come in the rows' order around it
    let children = try view.contentContainerView.accessibilityChildren().unwrap()
    expect(children.dropFirst().first as AnyObject) === appView
    expect(rows(of: children)) == Array(1 ..< 7)
  }

  func test_accessibilityChildren_setByTheApp_stay() throws {
    // given: rows of labels in a window, and an element of the app's own set as the document view's only child
    let (_, view) = makeLabelRowsView()
    view.refresh(animated: false)
    let element = NSAccessibilityElement()
    element.setAccessibilityRole(.group)
    view.contentContainerView.setAccessibilityChildren([element])

    // then: the children are the element that the app set
    let children = try view.contentContainerView.accessibilityChildren().unwrap()
    expect(children.count) == 1
    expect(children.first as AnyObject) === element
  }

  func test_accessibilityChildren_outsideAComposeView_comeInTheSubviewOrder() {
    // given: a document view outside a compose view, with labels out of their rows' order
    let documentView = ComposeView.DocumentView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))
    for row in [2, 0, 1] {
      let label = TextLabelView(frame: CGRect(x: 0, y: CGFloat(row) * Constants.rowHeight, width: 100, height: Constants.rowHeight))
      label.setAccessibilityValue("Row \(row)")
      documentView.addSubview(label)
    }

    // then: the children come in the subview order, as AppKit tells them
    expect(rows(of: documentView.accessibilityChildren())) == [2, 0, 1]
  }

  func test_accessibilityChildrenInNavigationOrder_ofLabelsOutOfTheItemsOrder_followTheRowsOnScreen() {
    // given: rows of labels in a window, scrolled by 2 rows, which leaves the label views out of the rows' order
    let (_, view) = makeLabelRowsView()
    view.refresh(animated: false)
    scroll(view, to: Constants.rowHeight)
    scroll(view, to: 2 * Constants.rowHeight)
    expect(rowsInSubviewOrder(of: view)) != Array(2 ..< 8)

    // then: the order to go through the children is the rows' order on screen, top to bottom
    expect(rows(of: view.contentContainerView.accessibilityChildrenInNavigationOrder())) == Array(2 ..< 8)
  }

  // MARK: - Helpers

  private enum Constants {

    static let rowCount = 60
    static let rowHeight: CGFloat = 50
    static let viewSize = CGSize(width: 100, height: 300)
  }

  /// Returns a view of rows of labels in a window, with a pool of its own.
  private func makeLabelRowsView() -> (TestWindow, ComposeView) {
    let window = TestWindow()
    let view = ComposeView {
      VStack {
        for row in 0 ..< Constants.rowCount {
          LabelNode("Row \(row)")
            .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
    view.renderablePool = RenderablePool()
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    window.contentView().addSubview(view)
    return (window, view)
  }

  /// Scrolls a view vertically, and renders it.
  private func scroll(_ view: ComposeView, to offset: CGFloat) {
    view.contentOffset = CGPoint(x: 0, y: offset)
    view.layoutIfNeeded()
  }

  /// Returns the label views in the content view, in the subview order, shown or hidden.
  private func labelViews(in view: ComposeView) -> [TextLabelView] {
    view.contentContainerView.subviews.compactMap { $0 as? TextLabelView }
  }

  /// Returns the rows that the shown label views show, in the subview order.
  private func rowsInSubviewOrder(of view: ComposeView) -> [Int] {
    rows(of: labelViews(in: view).filter { !$0.isHidden })
  }

  /// Returns the rows that accessibility elements of labels show, in their order, leaving out the other elements.
  private func rows(of elements: [Any]?) -> [Int] {
    (elements ?? []).compactMap { element in
      guard let value = (element as? NSAccessibilityProtocol)?.accessibilityValue() as? String, value.hasPrefix("Row ") else {
        return nil
      }
      return Int(value.dropFirst("Row ".count))
    }
  }
}

/// A view of an app's own, which assistive technologies see.
private final class AccessibleView: NSView {

  override func isAccessibilityElement() -> Bool {
    true
  }

  override func accessibilityRole() -> NSAccessibility.Role? {
    .group
  }
}
#endif
