//
//  ExtendedSRGB.swift
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
import Foundation

/// Colors in extended sRGB, the color space Core Animation interpolates colors of any color space in.
enum ExtendedSRGB {

  /// The extended sRGB color space.
  static let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB)! // swiftlint:disable:this force_unwrapping

  private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)! // swiftlint:disable:this force_unwrapping

  /// The extended sRGB components of the colors converted last, oldest first, kept on the main thread.
  private static var conversions: [(color: CGColor, components: SIMD4<Double>)] = []

  /// The components of a color in extended sRGB: red, green, blue and alpha.
  ///
  /// The components of an sRGB color are its extended sRGB components. A color of another color space is converted
  /// through ColorSync, which costs microseconds and dozens of allocations, so the main thread keeps the conversions of
  /// the colors converted last, as a render pass converts the same few colors for many layers, such as a theme's gray.
  ///
  /// - Parameter color: The color.
  /// - Returns: The components, or `nil` for a color that doesn't convert, such as a pattern.
  static func components(of color: CGColor) -> SIMD4<Double>? {
    // the named color spaces are shared instances, so an identity check tells an sRGB color without comparing names
    if let space = color.colorSpace, space === sRGB || space === colorSpace {
      return rgbaComponents(of: color)
    }

    guard Thread.isMainThread else {
      return convertedComponents(of: color)
    }
    if let conversion = conversions.last(where: { $0.color === color || CFEqual($0.color, color) }) {
      return conversion.components
    }
    guard let components = convertedComponents(of: color) else {
      return nil
    }
    if conversions.count == Constants.conversionCount {
      conversions.removeFirst()
    }
    conversions.append((color, components))
    return components
  }

  /// The color of extended sRGB components.
  ///
  /// - Parameter components: The components: red, green, blue and alpha.
  /// - Returns: The color.
  static func color(components: SIMD4<Double>) -> CGColor? {
    let components = (CGFloat(components.x), CGFloat(components.y), CGFloat(components.z), CGFloat(components.w))
    return withUnsafePointer(to: components) {
      $0.withMemoryRebound(to: CGFloat.self, capacity: 4) {
        CGColor(colorSpace: colorSpace, components: $0)
      }
    }
  }

  private static func convertedComponents(of color: CGColor) -> SIMD4<Double>? {
    color.converted(to: colorSpace, intent: .defaultIntent, options: nil).flatMap { rgbaComponents(of: $0) }
  }

  /// The components of a color of an RGB color space.
  private static func rgbaComponents(of color: CGColor) -> SIMD4<Double>? {
    color.components.map { SIMD4(Double($0[0]), Double($0[1]), Double($0[2]), Double($0[3])) }
  }

  // MARK: - Constants

  private enum Constants {

    /// How many converted colors the main thread keeps, more than a render pass usually converts.
    static let conversionCount = 8
  }
}
