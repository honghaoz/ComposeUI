//
//  Playground+TransitionView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/23/24.
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

  final class TransitionView: AnimatingComposeView {

    private var isShowing = true
    private var side: RenderableTransition.SlideSide = .left

    @ComposeContentBuilder
    override var content: ComposeContent {
      if isShowing {
        ColorNode(Colors.blueGray)
          .transition(.slide(from: side))
          .frame(width: 100, height: 40)
          .frame(.flexible, alignment: .center)
      } else {
        Empty()
      }
    }

    override func animate() {
      isShowing.toggle()
      if !isShowing {
        switch side {
        case .left:
          side = .bottom
        case .bottom:
          side = .right
        case .right:
          side = .top
        case .top:
          side = .left
        }
      }

      refresh()
    }
  }
}
