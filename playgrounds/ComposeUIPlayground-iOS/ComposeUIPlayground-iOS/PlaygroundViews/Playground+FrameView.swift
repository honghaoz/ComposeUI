//
//  Playground+FrameView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
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

  final class FrameView: AnimatingComposeView {

    private var color = Colors.blueGray
    private var borderColor = Color.white
    private var borderWidth = 2.0
    private var cornerRadius: CGFloat = 0
    private var size = CGSize(width: 100, height: 100)
    private var alignment: Layout.Alignment = .center
    private var padding = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    @ComposeContentBuilder
    override var content: ComposeContent {
      ColorNode(color)
        .border(color: borderColor, width: borderWidth)
        .cornerRadius(cornerRadius)
        .transition(.opacity(timing: .linear()))
        .animation(.spring(dampingRatio: 1, response: 1, initialVelocity: 0, delay: 0, speed: 1))
        .frame(size)
        .padding(padding)
        .frame(.flexible, alignment: alignment)
    }

    override func animate() {
      color = Colors.RetroApple.all.randomElement()! // swiftlint:disable:this force_unwrapping
      borderColor = Colors.RetroApple.all.randomElement()! // swiftlint:disable:this force_unwrapping
      borderWidth = CGFloat.random(in: 0 ... 25)
      cornerRadius = CGFloat.random(in: 0 ... 50)
      size = CGSize(width: CGFloat.random(in: 100 ... 200), height: CGFloat.random(in: 100 ... 200))
      alignment = Layout.Alignment.allCases.randomElement()! // swiftlint:disable:this force_unwrapping
      padding = EdgeInsets(top: CGFloat.random(in: 0 ... 20), left: CGFloat.random(in: 0 ... 20), bottom: CGFloat.random(in: 0 ... 20), right: CGFloat.random(in: 0 ... 20))

      refresh()
    }
  }
}
