//
//  DropShadowNodeTests.swift
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

class DropShadowNodeTests: XCTestCase {

  func test() throws {
    let view = ComposeView {
      VStack {
        DropShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), path: { renderItem in
          let size = renderItem.frame.size
          let cornerRadius = renderItem.layer.cornerRadius
          return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        })

        DropShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), paths: { renderItem in
          let size = renderItem.frame.size
          let cornerRadius = renderItem.layer.cornerRadius
          let shadowPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
          let cutoutPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height).insetBy(dx: 10, dy: 10), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
          return DropShadowPaths(shadowPath: shadowPath, cutoutPath: cutoutPath)
        })
      }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    #if canImport(AppKit)
    let shadowLayer1 = try unwrap(view.contentView().layer?.sublayers?.first)
    #endif
    #if canImport(UIKit)
    let shadowLayer1 = try unwrap(view.contentView().layer.sublayers?.first)
    #endif

    expect(shadowLayer1.shadowColor) == Color.black.cgColor
    expect(shadowLayer1.shadowOpacity) == 0.5
    expect(shadowLayer1.shadowRadius) == 10
    expect(shadowLayer1.shadowOffset) == CGSize(width: 2, height: 5)
    expect(shadowLayer1.shadowPath) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 0, cornerHeight: 0, transform: nil)

    #if canImport(AppKit)
    let shadowLayer2 = try unwrap(view.contentView().layer?.sublayers?[1])
    #endif
    #if canImport(UIKit)
    let shadowLayer2 = try unwrap(view.contentView().layer.sublayers?[1])
    #endif

    expect(shadowLayer2.shadowColor) == Color.black.cgColor
    expect(shadowLayer2.shadowOpacity) == 0.5
    expect(shadowLayer2.shadowRadius) == 10
    expect(shadowLayer2.shadowOffset) == CGSize(width: 2, height: 5)
    expect(shadowLayer2.shadowPath) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 0, cornerHeight: 0, transform: nil)

    let maskLayer = try unwrap(shadowLayer2.mask as? CAShapeLayer)
    expect(maskLayer.fillRule) == .evenOdd

    let cutoutPath = CGPath(roundedRect: CGRect(x: 10, y: 10, width: 80, height: 30), cornerWidth: 0, cornerHeight: 0, transform: nil)

    let radius: CGFloat = 10
    let offset = CGSize(width: 2, height: 5)
    let hExtraSize = radius + abs(offset.width) + 1000
    let vExtraSize = radius + abs(offset.height) + 1000
    let biggerBounds = cutoutPath.boundingBoxOfPath.insetBy(dx: -hExtraSize, dy: -vExtraSize)

    let biggerPath = CGMutablePath()
    biggerPath.addPath(CGPath(rect: biggerBounds, transform: nil))
    biggerPath.addPath(cutoutPath)
    expect(maskLayer.path) == biggerPath
  }
}
