//
//  CALayer+PrivateTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/21/25.
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

import QuartzCore

import ChouTiTest

@testable import ComposeUI

final class CALayerPrivateTests: XCTestCase {

  func test_invertsShadow() {
    // given: a layer
    let layer = CALayer()

    // then: the default value is false
    expect(layer.invertsShadow) == false
    expect(layer.value(forKey: "invertsShadow") as? Bool) == false

    // when: setting invertsShadow to true
    layer.invertsShadow = true

    // then: the property and the key value are true
    expect(layer.invertsShadow) == true
    expect(layer.value(forKey: "invertsShadow") as? Bool) == true

    // when: setting invertsShadow to false
    layer.invertsShadow = false

    // then: the property and the key value are false
    expect(layer.invertsShadow) == false
    expect(layer.value(forKey: "invertsShadow") as? Bool) == false

    // when: setting invertsShadow back to true
    layer.invertsShadow = true

    // then: the property and the key value are true
    expect(layer.invertsShadow) == true
    expect(layer.value(forKey: "invertsShadow") as? Bool) == true

    // when: setting the key value to false
    layer.setValue(false, forKey: "invertsShadow")

    // then: the property and the key value are false
    expect(layer.invertsShadow) == false
    expect(layer.value(forKey: "invertsShadow") as? Bool) == false

    // when: setting the key value to true
    layer.setValue(true, forKey: "invertsShadow")

    // then: the property and the key value are true
    expect(layer.invertsShadow) == true
    expect(layer.value(forKey: "invertsShadow") as? Bool) == true
  }
}
