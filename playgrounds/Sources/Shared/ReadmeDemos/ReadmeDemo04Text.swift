//
//  ReadmeDemo04Text.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/18/26.
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

import ComposeUI

/// The README "Text" demo: drawn labels and a selectable text view.
final class TextDemoView: ComposeView {

  @ComposeContentBuilder
  override var content: ComposeContent {
    VStack(alignment: .left, spacing: 8) {
      Label("Ready for liftoff 🚀")
        .font(.boldSystemFont(ofSize: 20))

      Label("Labels are drawn, and fast.")
        .textColor(.systemGray)

      Text(
        "Text is a selectable text view.",
        font: .systemFont(ofSize: 15)
      )
      .selectable()
      .fixedSize()
    }
  }
}
