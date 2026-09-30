//
//  ExtendedSRGBTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/26.
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

class ExtendedSRGBTests: XCTestCase {

  func test_components_sRGBColor_areItsComponents() throws {
    // given: an sRGB color and an extended sRGB color with components outside [0, 1]
    let sRGBColor = CGColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
    let extendedColor = try CGColor(colorSpace: unwrap(CGColorSpace(name: CGColorSpace.extendedSRGB)), components: [1.2, -0.1, 0.5, 1]).unwrap()

    // then: their components are read as they are
    expect(ExtendedSRGB.components(of: sRGBColor)) == SIMD4(0.2, 0.4, 0.6, 0.8)
    expect(ExtendedSRGB.components(of: extendedColor)) == SIMD4(1.2, -0.1, 0.5, 1)
  }

  func test_components_colorOfAnotherColorSpace_areItsConvertedComponents() throws {
    // given: colors of other color spaces: a gray, a Display P3 green outside sRGB, and a generic RGB red
    let colors = try [
      CGColor(gray: 0.3, alpha: 0.5),
      CGColor(colorSpace: unwrap(CGColorSpace(name: CGColorSpace.displayP3)), components: [0, 1, 0, 1]).unwrap(),
      CGColor(colorSpace: unwrap(CGColorSpace(name: CGColorSpace.genericRGBLinear)), components: [1, 0, 0, 1]).unwrap(),
    ]

    for color in colors {
      // when: reading its components twice, the second time from the kept conversion
      let components = [ExtendedSRGB.components(of: color), ExtendedSRGB.components(of: color)]

      // then: both are the color's components converted to extended sRGB
      let expected = try color.extendedSRGBComponents().map { Double($0) }
      for value in components {
        let value = try unwrap(value)
        expect([value.x, value.y, value.z, value.w], "\(color)") == expected
      }
    }
  }

  func test_components_moreColorsThanKept_convertsEach() throws {
    // given: twelve grays, more than the conversions kept
    let grays = (0 ..< 12).map { CGColor(gray: CGFloat($0) / 12, alpha: 1) }

    // when: reading their components twice around
    let components = (grays + grays).map { ExtendedSRGB.components(of: $0) }

    // then: each is its gray's converted components
    for (index, value) in components.enumerated() {
      let value = try unwrap(value)
      expect([value.x, value.y, value.z, value.w]) == (try grays[index % grays.count].extendedSRGBComponents().map { Double($0) })
    }
  }

  func test_components_offTheMainThread_converts() throws {
    // given: a gray
    let gray = CGColor(gray: 0.7, alpha: 1)

    // when: reading its components off the main thread
    var components: SIMD4<Double>?
    let didRead = expectation(description: "read off the main thread")
    DispatchQueue.global().async {
      expect(Thread.isMainThread) == false
      components = ExtendedSRGB.components(of: gray)
      didRead.fulfill()
    }
    wait(for: [didRead], timeout: 5)

    // then: they're its converted components, converted without the main thread's kept conversions
    let value = try unwrap(components)
    expect([value.x, value.y, value.z, value.w]) == (try gray.extendedSRGBComponents().map { Double($0) })
  }

  func test_components_pattern_isNil() throws {
    // given: a pattern color, which has no RGB components
    var callbacks = CGPatternCallbacks(version: 0, drawPattern: { _, _ in }, releaseInfo: nil)
    let pattern = try CGPattern(info: nil, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), matrix: .identity, xStep: 1, yStep: 1, tiling: .noDistortion, isColored: true, callbacks: &callbacks).unwrap()
    var alpha: CGFloat = 1
    let patternColor = try CGColor(patternSpace: CGColorSpace(patternBaseSpace: nil).unwrap(), pattern: pattern, components: &alpha).unwrap()

    // then: it has no extended sRGB components
    expect(ExtendedSRGB.components(of: patternColor)) == nil
  }

  func test_color_isTheColorOfTheComponentsInExtendedSRGB() throws {
    // when: making the color of components outside [0, 1]
    let color = try ExtendedSRGB.color(components: SIMD4(1.25, -0.5, 0.5, 0.75)).unwrap()

    // then: it's in extended sRGB with the components
    expect(color.colorSpace?.name) == CGColorSpace.extendedSRGB
    expect(color.components) == [1.25, -0.5, 0.5, 0.75]
  }
}
