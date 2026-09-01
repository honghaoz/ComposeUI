//
//  DropShadowLayerTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/14/26.
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

import QuartzCore

import ChouTiTest

@testable import ComposeUI

final class DropShadowLayerTests: XCTestCase {

  func test_update_clearsMaskWhenCutoutRemoved() throws {
    // given: a layer updated with a cutout, with an animation added on the mask
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    // with a cutout, a mask is installed to clip the shadow.
    layer.update(
      color: .black,
      opacity: 0.5,
      radius: 4,
      offset: .zero,
      path: { _ in CGPath(rect: rect, transform: nil) },
      cutoutPath: { _ in CGPath(rect: rect.insetBy(dx: 10, dy: 10), transform: nil) },
      animationTiming: nil
    )
    expect(layer.mask) != nil
    let mask = try layer.mask.unwrap()
    let animation = CABasicAnimation(keyPath: "path")
    animation.duration = 10
    mask.add(animation, forKey: "path")
    expect(mask.animationKeys()?.isEmpty) == false

    // when: updating without a cutout
    layer.update(
      color: .black,
      opacity: 0.5,
      radius: 4,
      offset: .zero,
      path: { _ in CGPath(rect: rect, transform: nil) },
      cutoutPath: nil,
      animationTiming: nil
    )

    // then: the previously installed mask is cleared, so the rendered state matches the inputs
    expect(layer.mask) == nil
    expect(mask.animationKeys() ?? []) == []
  }
}
