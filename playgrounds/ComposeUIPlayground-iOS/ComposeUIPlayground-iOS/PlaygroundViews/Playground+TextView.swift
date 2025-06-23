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
      Text(attributedString(alignment: .center))
        .numberOfLines(0)
        .fixedSize(width: false, height: true)
        .textContainerInset(horizontal: 16, vertical: 16)
        .border()
        .transition(.opacity())
        .overlay(alignment: .top) {
          ColorNode(.red.withAlphaComponent(0.1)).height(16)
        }
        .overlay(alignment: .bottom) {
          ColorNode(.red.withAlphaComponent(0.1)).height(16)
        }
        .overlay(alignment: .left) {
          ColorNode(.red.withAlphaComponent(0.1)).width(16)
        }
        .overlay(alignment: .right) {
          ColorNode(.red.withAlphaComponent(0.1)).width(16)
        }

      Spacer(height: 16)

      Text(
        longText,
        font: .systemFont(ofSize: 14),
        foregroundColor: ThemedColor(light: .purple, dark: .red),
        backgroundColor: ThemedColor(light: .red.withAlphaComponent(0.1), dark: .green.withAlphaComponent(0.1)),
        shadow: Themed<NSShadow>(
          light: {
            let shadow = NSShadow()
            shadow.shadowColor = Color.white.withAlphaComponent(0.33)
            shadow.shadowBlurRadius = 0
            shadow.shadowOffset = CGSize(width: 0, height: 1)
            return shadow
          }(),
          dark: {
            let shadow = NSShadow()
            shadow.shadowColor = Color.black.withAlphaComponent(0.5)
            shadow.shadowBlurRadius = 0
            shadow.shadowOffset = CGSize(width: 0, height: -1)
            return shadow
          }()
        ),
        textAlignment: .left
      )
      .fixedSize(width: false, height: true)
      .padding(horizontal: 4, vertical: 4)
      .border()
      .transition(.opacity())

      VStack(spacing: 10) {
        Spacer(height: 16)

        for (i, numberOfLines) in [1, 2, 0].enumerated() {
          VStack(spacing: 10) {
            for lineBreakMode in lineBreakModes {
              HStack(alignment: .top, spacing: 10) {
                for alignment in alignments {
                  Text(attributedString(alignment: alignment, lineBreakMode: numberOfLines == 1 ? lineBreakMode : nil))
                    .numberOfLines(numberOfLines)
                    .lineBreakMode(lineBreakMode)
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

private func attributedString(alignment: NSTextAlignment, lineBreakMode: NSLineBreakMode? = nil) -> NSAttributedString {
  let style = NSMutableParagraphStyle()
  style.alignment = alignment
  style.lineBreakMode = lineBreakMode ?? .byWordWrapping
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
