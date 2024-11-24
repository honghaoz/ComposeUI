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

  final class FrameView: ComposeView {

    private var color = Colors.blueGray
    private var size = CGSize(width: 100, height: 100)
    private var alignment: Layout.Alignment = .center
    private var padding = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    @ComposeContentBuilder
    override var content: ComposeContent {
      ColorNode(color)
        .transition(.opacity(timing: .linear(duration: 1)))
        .animation(.spring(dampingRatio: 0.8, response: 0.3))
        .frame(size)
        .padding(padding)
        .frame(.flexible, alignment: alignment)
        .overlay(alignment: .bottomRight) {
          LayerNode<CAShapeLayer>(update: { layer, context in
            layer.path = CGPath(roundedRect: layer.bounds, cornerWidth: 4, cornerHeight: 4, transform: nil)
            layer.lineWidth = 0.5
            layer.strokeColor = Color.black.withAlphaComponent(0.5).cgColor
            layer.fillColor = nil
          })
          .frame(width: 48, height: 16)
          .padding(bottom: 8, right: 8)
        }
    }

    #if canImport(AppKit)
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()

      if window != nil {
        startAnimation()
      }
    }
    #endif

    #if canImport(UIKit)
    override func didMoveToWindow() {
      super.didMoveToWindow()

      if window != nil {
        startAnimation()
      }
    }
    #endif

    private var isAnimating = false
    private func startAnimation() {
      guard !isAnimating else {
        return
      }

      isAnimating = true

      Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
        self?.animate()
      }
    }

    private func animate() {
      color = [Colors.blueGray, Colors.lightBlueGray, Colors.darkBlueGray].randomElement()! // swiftlint:disable:this force_unwrapping
      size = CGSize(width: CGFloat.random(in: 100 ... 200), height: CGFloat.random(in: 100 ... 200))
      alignment = Layout.Alignment.allCases.randomElement()! // swiftlint:disable:this force_unwrapping
      padding = EdgeInsets(top: CGFloat.random(in: 0 ... 20), left: CGFloat.random(in: 0 ... 20), bottom: CGFloat.random(in: 0 ... 20), right: CGFloat.random(in: 0 ... 20))

      refresh()
    }
  }
}
