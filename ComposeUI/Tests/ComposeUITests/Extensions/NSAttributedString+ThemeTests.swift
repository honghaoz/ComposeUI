//
//  NSAttributedString+ThemeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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

@testable import ComposeUI

class NSAttributedString_ThemeTests: XCTestCase {

  func test() {
    let lightShadow = NSShadow()
    lightShadow.shadowColor = Color.black
    let darkShadow = NSShadow()
    darkShadow.shadowColor = Color.white

    let attributedString = NSAttributedString(
      string: "Hello, world!",
      attributes: [
        .themedForegroundColor: ThemedColor(light: .red, dark: .blue),
        .themedBackgroundColor: ThemedColor(light: .green, dark: .yellow),
        .themedShadow: Themed<NSShadow>(light: lightShadow, dark: darkShadow),
      ]
    )

    let themedAttributedString = attributedString.apply(theme: .dark)
    let attributes = themedAttributedString.attributes(at: 0, effectiveRange: nil)
    expect(attributes[.foregroundColor] as? Color) == Color.blue
    expect(attributes[.backgroundColor] as? Color) == Color.yellow
    expect(attributes[.shadow] as? NSShadow) == darkShadow
  }
}
