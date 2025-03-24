//
//  Playground+LabelView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/21/25.
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

  final class LabelView: AnimatingComposeView {

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
      VStack(spacing: 10) {
        // single line, enough width
        HStack(spacing: 10) {
          for alignment in alignments {
            Text("ComposéUI")
              .font(.systemFont(ofSize: 12))
              .fixedSize(width: false, height: true)
              .numberOfLines(1)
              .textAlignment(alignment)
          }
        }
        .mapChildren {
          $0.width(100).border()
        }

        Spacer(height: 16)

        // single line, not enough width
        HStack(spacing: 10) {
          for alignment in alignments {
            VStack(spacing: 10) {
              for lineBreakMode in lineBreakModes {
                Text("ComposéUI")
                  .font(.systemFont(ofSize: 12))
                  .fixedSize(width: false, height: true) // make width flexible so that the container can set the width
                  .numberOfLines(1)
                  .textAlignment(alignment)
                  .lineBreakMode(lineBreakMode)
              }
            }
            .mapChildren { $0.width(50).border() }
          }
        }

        Spacer(height: 16)

        for (i, numberOfLines) in [0, 2].enumerated() {
          VStack(spacing: 10) {
            for lineBreakMode in lineBreakModes {
              HStack(alignment: .top, spacing: 10) {
                for alignment in alignments {
                  Text("Building UI using UIKit/AppKit with declarative syntax")
                    .font(.systemFont(ofSize: 12))
                    .numberOfLines(numberOfLines)
                    .textAlignment(alignment)
                    .lineBreakMode(lineBreakMode)
                }
              }
              .mapChildren { $0.width(100).border() }
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

private extension ComposeNode {

  func border() -> some ComposeNode {
    self.underlay {
      LayerNode()
        .border(color: Color.gray, width: 1)
    }
  }
}
