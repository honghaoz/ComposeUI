//
//  CALayer+ShownTransform.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/28/26.
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

/// Expects a committed layer to show a transform about a point of it, at the frame that it shows: Core Animation puts
/// each corner and the center where the transform about the point puts them.
///
/// - Parameters:
///   - layer: The layer, whose presentation shows the time to check.
///   - transform: The transform that the layer should show.
///   - anchor: The point that the transform applies about, in the unit space of the layer's bounds.
///   - tolerance: The distance within which a point is where the transform puts it, in points.
func expectShownTransform(of layer: CALayer,
                          _ transform: CATransform3D,
                          about anchor: UnitPoint,
                          within tolerance: CGFloat,
                          file: StaticString = #filePath,
                          line: UInt = #line) throws
{
  let presentation = try unwrap(layer.presentation(), file: file, line: line)
  let superlayer = try unwrap(presentation.superlayer, file: file, line: line)
  let bounds = presentation.bounds
  let size = bounds.size

  // the frame that the layer shows without its transform, and the point in it
  let originX = presentation.position.x - presentation.anchorPoint.x * size.width
  let originY = presentation.position.y - presentation.anchorPoint.y * size.height
  let pivotX = originX + CGFloat(anchor.x) * size.width
  let pivotY = originY + CGFloat(anchor.y) * size.height

  for point in [UnitPoint.topLeft, .topRight, .bottomLeft, .bottomRight, .center] {
    let shown = presentation.convert(
      CGPoint(x: bounds.minX + CGFloat(point.x) * size.width, y: bounds.minY + CGFloat(point.y) * size.height),
      to: superlayer
    )
    // the transform applies to the point's offset from the pivot, and projects it with its perspective
    let offsetX = CGFloat(point.x - anchor.x) * size.width
    let offsetY = CGFloat(point.y - anchor.y) * size.height
    let x = offsetX * transform.m11 + offsetY * transform.m21 + transform.m41
    let y = offsetX * transform.m12 + offsetY * transform.m22 + transform.m42
    let w = offsetX * transform.m14 + offsetY * transform.m24 + transform.m44
    expect(shown.x, "x of \(point)", file: file, line: line).to(beApproximatelyEqual(to: pivotX + x / w, within: tolerance))
    expect(shown.y, "y of \(point)", file: file, line: line).to(beApproximatelyEqual(to: pivotY + y / w, within: tolerance))
  }
}
