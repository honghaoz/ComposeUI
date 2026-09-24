//
//  PathPoints.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/23/26.
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

/// A path as the kinds and the points of its segments, so paths with the same segments can be added and subtracted
/// point by point, the way Core Animation interpolates them.
struct PathPoints: Equatable {

  /// The kinds of the segments, in order.
  let kinds: [CGPathElementType]

  /// The points of the segments, in order: one for a move or a line, two for a quad curve, three for a cubic curve and
  /// none for a close.
  let points: [CGPoint]

  /// Splits a path into the kinds and the points of its segments.
  ///
  /// - Parameter path: The path.
  init(_ path: CGPath) {
    var kinds: [CGPathElementType] = []
    var points: [CGPoint] = []
    path.applyWithBlock { element in
      let element = element.pointee
      kinds.append(element.type)
      points.append(contentsOf: UnsafeBufferPointer(start: element.points, count: PathPoints.pointCount(of: element.type)))
    }
    self.kinds = kinds
    self.points = points
  }

  private init(kinds: [CGPathElementType], points: [CGPoint]) {
    self.kinds = kinds
    self.points = points
  }

  /// The path of the segments.
  var path: CGPath {
    let path = CGMutablePath()
    var index = 0
    for kind in kinds {
      switch kind {
      case .moveToPoint:
        path.move(to: points[index])
      case .addLineToPoint:
        path.addLine(to: points[index])
      case .addQuadCurveToPoint:
        path.addQuadCurve(to: points[index + 1], control: points[index])
      case .addCurveToPoint:
        path.addCurve(to: points[index + 2], control1: points[index], control2: points[index + 1])
      case .closeSubpath:
        path.closeSubpath()
      @unknown default:
        break
      }
      index += PathPoints.pointCount(of: kind)
    }
    return path
  }

  /// Whether every point is at the origin, as in the difference of paths with the same points.
  var isZero: Bool {
    points.allSatisfy { $0 == .zero }
  }

  /// Whether every point is finite. A path of a null rect has its points at infinity, for example.
  var isFinite: Bool {
    points.allSatisfy { $0.x.isFinite && $0.y.isFinite }
  }

  /// Whether the other path has the same segments, so their points line up.
  ///
  /// - Parameter other: The other path.
  /// - Returns: `true` if the segments have the same kinds in the same order.
  func hasSameSegments(as other: PathPoints) -> Bool {
    kinds == other.kinds
  }

  /// Adds the points of a path with the same segments, multiplied by a factor, point by point.
  ///
  /// - Parameters:
  ///   - other: The path to add. It must have the same segments, see `hasSameSegments(as:)`.
  ///   - factor: The factor to multiply the other path's points by. Default to `1`.
  /// - Returns: The sum.
  func adding(_ other: PathPoints, multipliedBy factor: CGFloat = 1) -> PathPoints {
    ComposeUI.assert(hasSameSegments(as: other), "expected paths with the same segments") // TODO: if the predicate doesn't hold, what would happen?
    return PathPoints(
      kinds: kinds,
      points: zip(points, other.points).map { CGPoint(x: $0.x + $1.x * factor, y: $0.y + $1.y * factor) }
    )
  }

  /// Subtracts the points of a path with the same segments, point by point.
  ///
  /// - Parameter other: The path to subtract. It must have the same segments, see `hasSameSegments(as:)`.
  /// - Returns: The difference.
  func subtracting(_ other: PathPoints) -> PathPoints {
    adding(other, multipliedBy: -1)
  }

  private static func pointCount(of kind: CGPathElementType) -> Int {
    switch kind {
    case .moveToPoint,
         .addLineToPoint:
      return 1
    case .addQuadCurveToPoint:
      return 2
    case .addCurveToPoint:
      return 3
    case .closeSubpath:
      return 0
    @unknown default:
      return 0
    }
  }
}
