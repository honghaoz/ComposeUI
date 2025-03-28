//
//  Playground+TextView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/23/25.
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

  final class TextView: AnimatingComposeView {

    private let alignments: [NSTextAlignment] = [
      .left,
      .center,
      .right,
    ]

    private let lineBreakModes: [NSLineBreakMode] = [
      .byWordWrapping,
      .byCharWrapping,
      .byClipping,
      .byTruncatingTail,
      .byTruncatingMiddle,
      .byTruncatingHead,
    ]

    @ComposeContentBuilder
    override var content: ComposeContent {
      TextArea(attributedString(alignment: .center, lineBreakMode: .byWordWrapping))
        .numberOfLines(0)
        .fixedSize(width: false, height: true)
        .textContainerInset(horizontal: 4, vertical: 2)
        .intrinsicTextSizeAdjustment(width: 0, height: 10)
        .border()
        .transition(.opacity())

      VStack(spacing: 10) {
        Spacer(height: 16)

        for (i, numberOfLines) in [1, 2, 0].enumerated() {
          VStack(spacing: 10) {
            for lineBreakMode in lineBreakModes {
              HStack(alignment: .top, spacing: 10) {
                for alignment in alignments {
                  TextArea(attributedString(alignment: alignment, lineBreakMode: lineBreakMode))
                    .numberOfLines(numberOfLines)
                    .fixedSize(width: false, height: true)
                    .editable()
                    .transition(.opacity())
                }
              }
              .mapChildren { $0.border() }
            }
          }

          if i == 0 {
            Spacer(height: 16)
          }
        }
      }
      .mapChildren { node in
        guard !(node is HStack), !(node is VStack), !(node is Spacer) else {
          return node
        }

        return node.border()
      }
    }
  }
}

private let longText = """
Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
"""

private func attributedString(alignment: NSTextAlignment, lineBreakMode: NSLineBreakMode) -> NSAttributedString {
  let style = NSMutableParagraphStyle()
  style.alignment = alignment
  style.lineBreakMode = lineBreakMode
  style.lineBreakStrategy = []

  return NSAttributedString(string: longText, attributes: [
    .font: Font.systemFont(ofSize: 12),
    .themedForegroundColor: ThemedColor(light: Color.black.withAlphaComponent(0.9), dark: Color.white.withAlphaComponent(0.9)),
    .paragraphStyle: style,
  ])
}

private extension ComposeNode {

  func border() -> some ComposeNode {
    self.underlay {
      LayerNode()
        .border(color: Color.gray, width: 1)
    }
  }
}
