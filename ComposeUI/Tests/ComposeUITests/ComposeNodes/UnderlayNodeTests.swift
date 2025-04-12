//
//  UnderlayNodeTests.swift
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

import Foundation

import ChouTiTest

@testable import ComposeUI

class UnderlayNodeTests: XCTestCase {

  func test() {
    var content = ColorNode(.red)
      .underlay {
        ColorNode(.blue)
      }
      .background(alignment: .center, content: { ColorNode(.green) })
      .background(ColorNode(.green))

    content.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let items = content.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 50))
    guard items.count == 4 else {
      fail("Expected 4 items, got \(items.count)")
      return
    }

    // "underlay|U|color"
    expect(items[0].id.id) == .nested(
      parent: .standard(.underlay), suffix: "U", child: .standard(.color)
    )

    // "underlay|underlay|U|color"
    expect(items[1].id.id) == .nested(
      parent: .standard(.underlay),
      child: .nested(
        parent: .standard(.underlay), suffix: "U", child: .standard(.color)
      )
    )

    // "underlay|underlay|underlay|U|color"
    expect(items[2].id.id) == .nested(
      parent: .standard(.underlay),
      child: .nested(
        parent: .standard(.underlay),
        child: .nested(
          parent: .standard(.underlay), suffix: "U", child: .standard(.color)
        )
      )
    )

    // "underlay|underlay|underlay|color"
    expect(items[3].id.id) == .nested(
      parent: .standard(.underlay),
      child: .nested(
        parent: .standard(.underlay),
        child: .nested(
          parent: .standard(.underlay),
          child: .standard(.color)
        )
      )
    )
  }
}
