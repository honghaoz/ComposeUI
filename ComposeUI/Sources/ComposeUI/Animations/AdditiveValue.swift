//
//  AdditiveValue.swift
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

/// A value of a kind that animates additively, a number, `CGSize` or `CGPoint`, as two components.
///
/// A number uses the first component and leaves the second at zero, so the component-wise math is the same for every kind.
struct AdditiveValue {

  private enum Kind {
    case number
    case size
    case point
  }

  private let kind: Kind

  /// The components: the number and zero, width and height, or x and y.
  private let components: SIMD2<Double>

  /// Creates the value from a number, `CGSize` or `CGPoint`, as Core Animation boxes them.
  ///
  /// - Returns: `nil` for a value of another kind.
  init?(_ value: Any) {
    if let size = value as? CGSize {
      kind = .size
      components = SIMD2(size.width, size.height)
    } else if let point = value as? CGPoint {
      kind = .point
      components = SIMD2(point.x, point.y)
    } else if let number = value as? NSNumber {
      kind = .number
      components = SIMD2(number.doubleValue, 0)
    } else {
      return nil
    }
  }

  private init(kind: Kind, components: SIMD2<Double>) {
    self.kind = kind
    self.components = components
  }

  /// The value as Core Animation boxes it.
  var value: Any {
    switch kind {
    case .number:
      return components.x
    case .size:
      return CGSize(width: components.x, height: components.y)
    case .point:
      return CGPoint(x: components.x, y: components.y)
    }
  }

  /// The zero of the value's kind.
  var zero: AdditiveValue {
    AdditiveValue(kind: kind, components: .zero)
  }

  /// Whether every component is zero.
  var isZero: Bool {
    components == .zero
  }

  func isSameKind(as other: AdditiveValue) -> Bool {
    kind == other.kind
  }

  /// The value with every component multiplied by `factor`.
  func scaled(by factor: Double) -> AdditiveValue {
    AdditiveValue(kind: kind, components: components * factor)
  }

  /// The component-wise sum of two values of the same kind.
  static func + (lhs: AdditiveValue, rhs: AdditiveValue) -> AdditiveValue {
    AdditiveValue(kind: lhs.kind, components: lhs.components + rhs.components)
  }

  static func += (lhs: inout AdditiveValue, rhs: AdditiveValue) {
    lhs = lhs + rhs
  }

  /// The component-wise difference of two values of the same kind.
  static func - (lhs: AdditiveValue, rhs: AdditiveValue) -> AdditiveValue {
    AdditiveValue(kind: lhs.kind, components: lhs.components - rhs.components)
  }
}
