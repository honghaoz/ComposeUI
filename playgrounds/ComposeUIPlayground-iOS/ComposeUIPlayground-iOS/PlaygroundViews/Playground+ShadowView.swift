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
    private var cornerRadius = 0.01 // for smooth path animation

    private var shadowColor = Color.black
    private var shadowOpacity = 0.5
    private var shadowRadius = 10.0
    private var shadowOffset = CGSize(width: 0, height: 0)

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack {
        Spacer()

        // animated shadow
        HStack {
          Spacer()

          ColorNode(.white)
            .transition(.none)
            .border(color: .black, width: 1)
            .cornerRadius(cornerRadius)
            .dropShadow(color: shadowColor, opacity: shadowOpacity, radius: shadowRadius, offset: shadowOffset, path: { [unowned self] renderItem in // swiftlint:disable:this unowned_variable
              let size = renderItem.frame.size
              let cornerRadius = self.cornerRadius
              return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            })
            .transition(.opacity(timing: .linear()))
            .animation(.spring(dampingRatio: 1, response: 1, initialVelocity: 0, delay: 0, speed: 1))
            .frame(size)

          Spacer()

          ColorNode(.white)
            .border(color: .black, width: 1)
            .cornerRadius(cornerRadius)
            .shadow(color: shadowColor, opacity: shadowOpacity, radius: shadowRadius, offset: shadowOffset, path: { renderItem in
              let size = renderItem.frame.size
              let cornerRadius = renderItem.layer.cornerRadius
              return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            })
            .transition(.opacity(timing: .linear()))
            .animation(.spring(dampingRatio: 1, response: 1, initialVelocity: 0, delay: 0, speed: 1))
            .frame(size)

          Spacer()
        }

        Spacer()

        // static shadow
        HStack {
          Spacer()

          ColorNode(.white)
            .border(color: .black, width: 1)
            .cornerRadius(16)
            .dropShadow(
              color: ThemedColor(light: .black, dark: .yellow),
              opacity: Themed<CGFloat>(light: 0.5, dark: 0.8),
              radius: Themed<CGFloat>(light: 8, dark: 16),
              offset: Themed<CGSize>(light: CGSize(width: 5, height: 5), dark: CGSize(width: 10, height: 10)),
              path: { renderItem in
                let size = renderItem.frame.size
                let cornerRadius: CGFloat = 16
                return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
              }
            )
            .frame(width: 100, height: 80)

          Spacer()

          ColorNode(.white)
            .border(color: .black, width: 1)
            .cornerRadius(16)
            .shadow(
              color: ThemedColor(light: .black, dark: .yellow),
              opacity: Themed<CGFloat>(light: 0.5, dark: 0.8),
              radius: Themed<CGFloat>(light: 8, dark: 16),
              offset: Themed<CGSize>(light: CGSize(width: 5, height: 5), dark: CGSize(width: 10, height: 10)),
              path: { renderItem in
                let size = renderItem.frame.size
                let cornerRadius = renderItem.layer.cornerRadius
                return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
              }
            )
            .frame(width: 100, height: 80)

          Spacer()
        }

        Spacer(height: 32)
      }

      .frame(.flexible)
    }

    override func animate() {
      size = CGSize(width: CGFloat.random(in: 50 ... 150), height: CGFloat.random(in: 50 ... 150))
      cornerRadius = CGFloat.random(in: 0 ... 25)

      shadowColor = Colors.RetroApple.all.randomElement()! // swiftlint:disable:this force_unwrapping
      shadowOpacity = CGFloat.random(in: 0.1 ... 1)
      shadowRadius = CGFloat.random(in: 1 ... 16)
      shadowOffset = CGSize(width: CGFloat.random(in: -20 ... 20), height: CGFloat.random(in: -20 ... 20))

      refresh()
    }
  }
}
