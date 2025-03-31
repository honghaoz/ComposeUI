//
//  Playground+ShadowView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/30/25.
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

  final class ShadowView: AnimatingComposeView {

    private var size = CGSize(width: 100, height: 100)
    private var cornerRadius = 0.0

    private var shadowColor = Color.black
    private var shadowOpacity = 0.5
    private var shadowRadius = 10.0
    private var shadowOffset = CGSize(width: 0, height: 0)

    @ComposeContentBuilder
    override var content: ComposeContent {
      ColorNode(.white)
        .border(color: .black, width: 1)
        .cornerRadius(cornerRadius)
        .underlay {
          LayerNode()
            .cornerRadius(cornerRadius)
            .shadow(color: shadowColor, opacity: shadowOpacity, radius: shadowRadius, offset: shadowOffset, path: { renderItem in
              let size = renderItem.frame.size
              let cornerRadius = renderItem.layer.cornerRadius
              return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            })
        }
        .transition(.opacity(timing: .linear()))
        .animation(.spring(dampingRatio: 1, response: 1, initialVelocity: 0, delay: 0, speed: 1))
        .frame(size)
        .frame(.flexible)
    }

    override func animate() {
      size = CGSize(width: CGFloat.random(in: 100 ... 200), height: CGFloat.random(in: 100 ... 200))
      cornerRadius = CGFloat.random(in: 0 ... 50)

      shadowColor = Colors.RetroApple.all.randomElement()! // swiftlint:disable:this force_unwrapping
      shadowOpacity = CGFloat.random(in: 0.1 ... 1)
      shadowRadius = CGFloat.random(in: 1 ... 16)
      shadowOffset = CGSize(width: CGFloat.random(in: -20 ... 20), height: CGFloat.random(in: -20 ... 20))

      refresh()
    }
  }
}
