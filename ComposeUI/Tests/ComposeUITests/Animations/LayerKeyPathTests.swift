//
//  LayerKeyPathTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/9/26.
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

class LayerKeyPathTests: XCTestCase {

  func test_objectiveC_animatedKeyPath() {
    // given: the key paths the framework animates that Swift would copy
    let keyPaths = [
      "backgroundColor",
      "bounds.size",
      "borderColor",
      "borderWidth",
      "cornerRadius",
      "shadowColor",
      "shadowOpacity",
      "shadowRadius",
      "shadowOffset",
      "shadowPath",
      "transform.scale",
    ]

    for keyPath in keyPaths {
      // when: looking up the key path to pass to Core Animation
      let objectiveCKeyPath = LayerKeyPath.objectiveC(keyPath)

      // then: it's the same key path, passed to Objective-C as the same string every time instead of a new copy
      expect(objectiveCKeyPath) == keyPath
      expect(objectiveCKeyPath as NSString) === (LayerKeyPath.objectiveC(keyPath) as NSString)
    }
  }

  func test_objectiveC_otherKeyPath() {
    // given: key paths shorter and longer than the lengths Swift copies, and of those lengths but not in the lookup
    let keyPaths = [
      "",
      "opacity",
      "zPosition",
      "position.x",
      "anchorPoint",
      "frame.size.width",
      "transform.rotation.z",
    ]

    for keyPath in keyPaths {
      // when: looking up a key path the framework doesn't keep as an Objective-C string
      let objectiveCKeyPath = LayerKeyPath.objectiveC(keyPath)

      // then: it's returned as it is
      expect(objectiveCKeyPath) == keyPath
    }
  }
}
