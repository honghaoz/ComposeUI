//
//  ReadmeDemo02Layout.swift
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

/// The README "Layout" demo: a list row built with stacks.
final class LayoutDemoView: ComposeView {

  @ComposeContentBuilder
  override var content: ComposeContent {
    HStack(spacing: 12) {
      ZStack {
        ColorNode(.systemBlue).cornerRadius(22)
        Label("DR").textColor(.white)
      }
      .frame(width: 44, height: 44)
      VStack(alignment: .left, spacing: 4) {
        Label("Design Review")
        Label("Today, 3:00 PM")
          .textColor(.systemGray)
      }
      Spacer()
      Label("Join").textColor(.systemBlue)
    }
    .padding(16)
    .background {
      ColorNode(.white).cornerRadius(12)
    }
  }
}
