//
//  CGColor+Components.swift
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

import CoreGraphics

import ChouTiTest

extension CGColor {

  /// The color's red, green, blue and alpha components in sRGB, which clamps them to [0, 1].
  func sRGBComponents() throws -> [CGFloat] {
    try components(in: CGColorSpace.sRGB)
  }

  /// The color's red, green, blue and alpha components in extended sRGB, the color space Core Animation interpolates
  /// colors in.
  func extendedSRGBComponents() throws -> [CGFloat] {
    try components(in: CGColorSpace.extendedSRGB)
  }

  private func components(in spaceName: CFString) throws -> [CGFloat] {
    let space = try unwrap(CGColorSpace(name: spaceName))
    return try unwrap(converted(to: space, intent: .defaultIntent, options: nil)?.components)
  }
}

/// The components a progress of the way between two colors' extended sRGB components.
func interpolatedExtendedSRGBComponents(from: CGColor, to: CGColor, progress: CGFloat) throws -> [CGFloat] {
  try zip(from.extendedSRGBComponents(), to.extendedSRGBComponents()).map { $0 + ($1 - $0) * progress }
}

/// Expects a color's extended sRGB components, within a tolerance.
///
/// - Parameters:
///   - color: The color.
///   - expected: The expected red, green, blue and alpha components in extended sRGB.
///   - tolerance: How far each component may be from the expected one.
func expectExtendedSRGBComponents(of color: CGColor,
                                  toBe expected: [CGFloat],
                                  within tolerance: CGFloat = 1e-6,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) throws
{
  let components = try color.extendedSRGBComponents()
  expect(components.count, "\(components)", file: file, line: line) == expected.count
  for (component, expectedComponent) in zip(components, expected) {
    expect(component, "\(components)", file: file, line: line).to(beApproximatelyEqual(to: expectedComponent, within: tolerance))
  }
}
