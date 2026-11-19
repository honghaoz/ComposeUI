//
//  ReadmeDemo10Scrolling.swift
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

/// The README "Scrolling and performance" demo: a music library of a thousand songs in one view.
final class ScrollingDemoView: ComposeView {

  @ComposeContentBuilder
  override var content: ComposeContent {
    let titles = [
      "Midnight Drive", "Paper Lanterns",
      "Northern Lights", "Slow Tides",
      "City of Glass", "Summer Static",
      "Afterglow",
    ]

    let artists = [
      "Nova Park", "The Tidelines",
      "Ada Rivers", "June & the Echoes",
      "Low Orbit",
    ]

    let colors: [Color] = [
      .systemBlue, .systemTeal, .systemGreen,
      .systemOrange, .systemRed,
    ]

    VStack {
      for i in 1 ... 1000 {
        HStack(spacing: 12) {
          Label("\(i)")
            .textColor(.systemGray)
            .frame(
              width: 32,
              height: .intrinsic
            )

          ColorNode(colors[i % colors.count])
            .frame(40).cornerRadius(8)

          VStack(
            alignment: .left,
            spacing: 2
          ) {
            Label(titles[i % titles.count])
            Label(artists[i % artists.count])
              .textColor(.systemGray)
          }

          Spacer()

          Label("3:\(10 + i * 7 % 50)")
            .textColor(.systemGray)
        }
        .padding(horizontal: 16, vertical: 8)
      }
    }
  }
}
