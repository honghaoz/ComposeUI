//
//  InnerShadowNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/5/25.
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

import ChouTiTest

import ComposeUI

class InnerShadowNodeTests: XCTestCase {

  func test() throws {
    let view = ComposeView {
      VStack {
        InnerShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), path: { renderItem in
          let size = renderItem.frame.size
          let cornerRadius = renderItem.layer.cornerRadius
          return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        })
      }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    #if canImport(AppKit)
    let shadowLayer = try unwrap(view.contentView().layer?.sublayers?[0])
    #endif
    #if canImport(UIKit)
    let shadowLayer = try unwrap(view.contentView().layer.sublayers?[0])
    #endif

    expect(shadowLayer.shadowColor) == Color.black.cgColor
    expect(shadowLayer.shadowOpacity) == 0.5
    expect(shadowLayer.shadowRadius) == 10
    expect(shadowLayer.shadowOffset) == CGSize(width: 2, height: 5)
    expect(shadowLayer.shadowPath) != nil

    let maskLayer = try unwrap(shadowLayer.mask as? CAShapeLayer)
    expect(maskLayer.path) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerWidth: 0, cornerHeight: 0, transform: nil)
  }
}
