//
//  ReadmeDemo03Styling.swift
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

import CoreGraphics

import ComposeUI

/// The README "Styling" demo: a border, a drop shadow and an inner shadow.
final class StylingDemoView: ComposeView {

  @ComposeContentBuilder
  override var content: ComposeContent {
    let path = { (size: CGSize) in
      CGPath(
        roundedRect: CGRect(
          origin: .zero,
          size: size
        ),
        cornerWidth: 16,
        cornerHeight: 16,
        transform: nil
      )
    }

    HStack(spacing: 24) {
      ColorNode(.white)
        .frame(80).cornerRadius(16)
        .border(color: .systemBlue, width: 2)

      ColorNode(.white)
        .frame(80).cornerRadius(16)
        .dropShadow(
          color: .black,
          opacity: 0.2,
          radius: 8,
          offset: .zero,
          path: path
        )

      ColorNode(.white)
        .frame(80).cornerRadius(16)
        .innerShadow(
          color: .black,
          opacity: 0.3,
          radius: 6,
          offset: .zero,
          path: path
        )
    }
  }
}
