//
//  ReadmeDemo09Interop.swift
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

#if canImport(AppKit)

import AppKit
import SwiftUI

import ComposeUI

/// The README "Interop" demo: a native view, a layer and a SwiftUI view in one stack.
final class InteropDemoView: ComposeView {

  @ComposeContentBuilder
  override var content: ComposeContent {
    HStack(spacing: 32) {
      ViewNode(make: { _ in
        let toggle = NSSwitch()
        toggle.wantsLayer = true
        toggle.state = .on
        return toggle
      })
      .frame(width: 38, height: 22)

      LayerNode<CAShapeLayer>(
        update: { dot, _ in
          dot.path = CGPath(
            ellipseIn: dot.bounds,
            transform: nil
          )
          dot.fillColor =
            NSColor.systemOrange.cgColor
        }
      )
      .frame(40)

      SwiftUIViewNode {
        ProgressView(value: 0.6)
      }
      .frame(width: 100, height: 20)
    }
  }
}

#endif
