//
//  CGRect+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

extension CGRect {

  /// Translate the rectangle by a given point.
  ///
  /// - Parameters:
  ///   - dx: The horizontal translation.
  ///   - dy: The vertical translation.
  /// - Returns: A new rectangle translated by the given point.
  @inlinable
  @inline(__always)
  func translate(dx: CGFloat = 0, dy: CGFloat = 0) -> CGRect {
    CGRect(origin: CGPoint(x: origin.x + dx, y: origin.y + dy), size: size)
  }

  /// Translate the rectangle by a given point.
  ///
  /// - Parameter point: The point to translate the rectangle by.
  /// - Returns: A new rectangle translated by the given point.
  @inlinable
  @inline(__always)
  func translate(_ point: CGPoint) -> CGRect {
    CGRect(origin: CGPoint(x: origin.x + point.x, y: origin.y + point.y), size: size)
  }

  /// Rounds the rectangle to the nearest pixel size based on the given scale factor.
  /// So that the view can be rendered without subpixel rendering artifacts.
  ///
  /// - Parameter scaleFactor: The scale factor of the screen.
  /// - Returns: The rounded rectangle.
  func rounded(scaleFactor: CGFloat) -> CGRect {
    if isNull || isInfinite {
      return self
    }

    let pixelWidth: CGFloat = 1 / scaleFactor

    let x = origin.x.round(nearest: pixelWidth)
    let y = origin.y.round(nearest: pixelWidth)
    let width = width.round(nearest: pixelWidth)
    let height = height.round(nearest: pixelWidth)
    return CGRect(x: x, y: y, width: width, height: height)
  }

  /// Calls a block with each part of the rectangle outside another rectangle, as up to four rectangles that don't
  /// overlap: the parts before and after the other rectangle along the y axis, across the whole width, then the parts
  /// before and after it along the x axis, between them.
  ///
  /// - Parameters:
  ///   - other: The rectangle whose area the parts leave out.
  ///   - body: The block to call with each part, none of which is empty.
  func forEachPart(outside other: CGRect, _ body: (CGRect) -> Void) {
    let overlap = intersection(other)
    guard !overlap.isEmpty else {
      if !isEmpty {
        body(self)
      }
      return
    }

    if overlap.minY > minY {
      body(CGRect(x: minX, y: minY, width: width, height: overlap.minY - minY))
    }
    if maxY > overlap.maxY {
      body(CGRect(x: minX, y: overlap.maxY, width: width, height: maxY - overlap.maxY))
    }
    if overlap.minX > minX {
      body(CGRect(x: minX, y: overlap.minY, width: overlap.minX - minX, height: overlap.height))
    }
    if maxX > overlap.maxX {
      body(CGRect(x: overlap.maxX, y: overlap.minY, width: maxX - overlap.maxX, height: overlap.height))
    }
  }

  #if canImport(AppKit)
  func inset(by insets: EdgeInsets) -> CGRect {
    guard insets.top != 0 || insets.left != 0 || insets.bottom != 0 || insets.right != 0 else {
      return self
    }

    return CGRect(
      x: origin.x + insets.left,
      y: origin.y + insets.top,
      width: width - insets.left - insets.right,
      height: height - insets.top - insets.bottom
    )
  }
  #endif
}
