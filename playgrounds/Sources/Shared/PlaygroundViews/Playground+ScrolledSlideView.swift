//
//  Playground+ScrolledSlideView.swift
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ComposeUI

extension Playground {

  /// A page for slide transitions in a scrolled view.
  ///
  /// A list that scrolls along both axes shows a box in the middle of its visible area, which slides in from the chosen
  /// side and out toward it. The box should start and end just outside the list's visible area, wherever the list is
  /// scrolled.
  final class ScrolledSlideView: ComposeView {

    /// The page's preferred height, for the hosting content view's layout.
    static let preferredHeight: CGFloat = 360

    private var side: RenderableTransition.SlideSide = .bottom

    /// The box's origin in the list's content, or `nil` while the box isn't shown.
    private var boxOrigin: CGPoint?

    private lazy var listView = ComposeView { [weak self] in
      self?.listContent ?? Empty()
    }

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(spacing: 12) {
        Label("Scroll the list, then insert the box. It should slide in from just outside the list's visible area on the chosen side, and slide out the same way.")
          .font(.systemFont(ofSize: 12))
          .textColor(Color.gray)
          .numberOfLines(0)

        ViewNode(listView)
          .flexibleSize()
          .underlay {
            LayerNode()
              .border(color: Color.gray, width: 1)
          }
          .frame(width: .flexible, height: Constants.listHeight)

        HStack(spacing: 12) {
          Playground.button(title: boxOrigin == nil ? "Insert box" : "Remove box", fontSize: 14) { [weak self] in
            self?.toggleBox()
          }

          Playground.button(title: "Side: \(side)", fontSize: 14) { [weak self] in
            self?.cycleSide()
          }
        }
        .frame(width: .flexible, height: 36)
      }
      .padding(12)
    }

    private var listContent: ComposeContent {
      VStack(spacing: 0) {
        for row in 0 ..< Constants.rowCount {
          HStack(spacing: 0) {
            for column in 0 ..< Constants.columnCount {
              Label("\(row), \(column)")
                .font(.systemFont(ofSize: 11))
                .textColor(Color.gray)
                .frame(Constants.cellSize)
                .background {
                  ColorNode((row + column).isMultiple(of: 2) ? Constants.cellColor : Constants.alternateCellColor)
                }
            }
          }
        }
      }
      .overlay(alignment: .topLeft) {
        if let boxOrigin {
          ColorNode(Colors.RetroApple.orange)
            .frame(Constants.boxSize)
            .transition(.slide(from: side, timing: Constants.slideTiming))
            .offset(boxOrigin)
        }
      }
    }

    private func toggleBox() {
      if boxOrigin == nil {
        let visibleArea = CGRect(origin: listView.contentOffset, size: listView.visibleSize)
        boxOrigin = CGPoint(
          x: (visibleArea.midX - Constants.boxSize.width / 2).rounded(),
          y: (visibleArea.midY - Constants.boxSize.height / 2).rounded()
        )
      } else {
        boxOrigin = nil
      }
      listView.refresh(animated: true)
      refresh(animated: false)
    }

    private func cycleSide() {
      switch side {
      case .bottom:
        side = .left
      case .left:
        side = .top
      case .top:
        side = .right
      case .right:
        side = .bottom
      }
      // a box removes with the transition of the render that last updated it, so the list renders the new side before
      // the next removal
      listView.refresh(animated: false)
      refresh(animated: false)
    }

    // MARK: - Constants

    private enum Constants {

      /// The height of the list.
      static let listHeight: CGFloat = 220

      /// The number of rows in the list.
      static let rowCount = 30

      /// The number of columns in the list, which make it wider than the page, so it scrolls sideways too.
      static let columnCount = 10

      /// The size of each cell in the list.
      static let cellSize = CGSize(width: 90, height: 36)

      /// The size of the box.
      static let boxSize = CGSize(width: 120, height: 60)

      /// The slide's timing, slow enough to see where the box comes from.
      static let slideTiming: AnimationTiming = .easeInEaseOut(duration: 1.2)

      /// The background color of every other cell.
      static let cellColor = Color.gray.withAlphaComponent(0.12)

      /// The background color of the cells between them.
      static let alternateCellColor = Color.gray.withAlphaComponent(0.24)
    }
  }
}
