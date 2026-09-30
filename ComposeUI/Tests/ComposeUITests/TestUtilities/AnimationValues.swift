//
//  AnimationValues.swift
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

// Core Animation gives animation values, presentation values and KVC values as `Any`. A conditional cast to a Core
// Foundation type succeeds for any object, and a forced one crashes on use instead of failing the test, so colors and
// paths are told apart by their type IDs.

/// The value as a color.
///
/// - Parameter value: The value.
/// - Returns: The color.
/// - Throws: When the value isn't a color, such as an animation's unresolved from value, `NSNull`.
func colorValue(_ value: Any?, file: StaticString = #filePath, line: UInt = #line) throws -> CGColor {
  let color = object(value, withTypeID: CGColor.typeID).map { unsafeDowncast($0, to: CGColor.self) }
  return try unwrap(color, "expected a color, got \(String(describing: value))", file: file, line: line)
}

/// The value as a path.
///
/// - Parameter value: The value.
/// - Returns: The path.
/// - Throws: When the value isn't a path.
func pathValue(_ value: Any?, file: StaticString = #filePath, line: UInt = #line) throws -> CGPath {
  let path = object(value, withTypeID: CGPath.typeID).map { unsafeDowncast($0, to: CGPath.self) }
  return try unwrap(path, "expected a path, got \(String(describing: value))", file: file, line: line)
}

/// The values of a keyframe animation of paths.
///
/// - Parameter animation: The animation.
/// - Returns: The paths.
/// - Throws: When the animation has no values, or a value isn't a path.
func pathValues(of animation: CAKeyframeAnimation, file: StaticString = #filePath, line: UInt = #line) throws -> [CGPath] {
  try unwrap(animation.values, file: file, line: line).map { try pathValue($0, file: file, line: line) }
}

/// The scalar of a number value, for `CALayer.predictedValue(forKeyPath:at:scalar:)`.
func numberScalar(_ value: Any) throws -> CGFloat {
  try CGFloat((value as? NSNumber).unwrap().doubleValue)
}

/// The scalar of a color value, its blue component in sRGB, for `CALayer.predictedValue(forKeyPath:at:scalar:)`.
func blueScalar(_ value: Any) throws -> CGFloat {
  try colorValue(value).sRGBComponents()[2]
}

/// The value as an object of a Core Foundation type, or `nil` for a value of another type or no value.
private func object(_ value: Any?, withTypeID typeID: CFTypeID) -> AnyObject? {
  guard let object = value.map({ $0 as AnyObject }), CFGetTypeID(object) == typeID else {
    return nil
  }
  return object
}
