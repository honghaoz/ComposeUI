//
//  NSBezierPath+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/4/21.
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

public extension NSBezierPath {

  /// Creates and returns a new Bézier path object with the reversed contents of the current path.
  ///
  /// - Returns: A new Bézier path object with the same path shape but for which the path has been created in the reverse direction.
  @inlinable
  @inline(__always)
  func reversing() -> NSBezierPath {
    reversed
  }

  /// Appends a straight line to the path.
  ///
  /// This method creates a straight line segment starting at the current point and ending at the point specified by the point parameter.
  /// After adding the line segment, this method updates the current point to the value in point.
  ///
  /// You must set the path’s current point (using the `move(to:)` method or through the previous creation of a line or curve segment)
  /// before you call this method. If the path is empty, this method does nothing.
  ///
  /// - Parameter point: The destination point of the line segment, specified in the current coordinate system.
  @inlinable
  @inline(__always)
  func addLine(to point: CGPoint) {
    line(to: point)
  }

  /// Appends a cubic Bézier curve to the path.
  ///
  /// This method appends a cubic Bézier curve from the current point to the end point specified by the `endPoint` parameter.
  ///
  /// You must set the path's current point (using the `move(to:)` method or through the creation of a preceding line or curve
  /// segment) before you invoke this method. If the path is empty, this method raises an `genericException` exception.
  ///
  /// - Parameters:
  ///   - endPoint: The destination point of the curve segment, specified in the current coordinate system
  ///   - controlPoint1: The point that determines the shape of the curve near the current point.
  ///   - controlPoint2: The point that determines the shape of the curve near the destination point.
  @inlinable
  @inline(__always)
  func addCurve(to endPoint: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
    curve(to: endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
  }

  /// Appends a quadratic Bézier curve to the path.
  ///
  /// This method appends a quadratic Bézier curve from the current point to the end point specified by the endPoint parameter.
  ///
  /// You must set the path's current point (using the `move(to:)` method or through the creation of a preceding line or curve
  /// segment) before you invoke this method. If the path is empty, this method raises an `genericException` exception.
  ///
  /// - Parameters:
  ///   - endPoint: The destination point of the curve segment, specified in the current coordinate system
  ///   - controlPoint: The control point of the curve.
  func addQuadCurve(to point: CGPoint, controlPoint: CGPoint) {
    if #available(macOS 14.0, *) {
      curve(to: point, controlPoint: controlPoint)
    } else {
      addQuadCurve_below_macOS14(to: point, controlPoint: controlPoint)
    }
  }

  @available(macOS, obsoleted: 14.0)
  private func addQuadCurve_below_macOS14(to point: CGPoint, controlPoint: CGPoint) {
    let (d1x, d1y) = (controlPoint.x - currentPoint.x, controlPoint.y - currentPoint.y)
    let (d2x, d2y) = (point.x - controlPoint.x, point.y - controlPoint.y)
    let cp1 = CGPoint(x: controlPoint.x - d1x / 3.0, y: controlPoint.y - d1y / 3.0)
    let cp2 = CGPoint(x: controlPoint.x + d2x / 3.0, y: controlPoint.y + d2y / 3.0)
    curve(to: point, controlPoint1: cp1, controlPoint2: cp2)
  }

  // MARK: - CGPath

  /// The Core Graphics representation of the path.
  @available(macOS, obsoleted: 14.0)
  var cgPath: CGPath {
    get {
      let path = CGMutablePath()
      var points = [CGPoint](repeating: .zero, count: 3)

      for i in 0 ..< elementCount {
        let type = element(at: i, associatedPoints: &points)
        switch type {
        case .moveTo:
          path.move(to: points[0])
        case .lineTo:
          path.addLine(to: points[0])
        case .quadraticCurveTo:
          path.addQuadCurve(to: points[1], control: points[0])
        case .cubicCurveTo:
          path.addCurve(to: points[2], control1: points[0], control2: points[1])
        case .closePath:
          path.closeSubpath()
        @unknown default:
          ComposeUI.assertFailure("Unknown CGPath element type: \(type)")
        }
      }

      return path
    }
    set {
      self.removeAllPoints()
      self.addCGPath(newValue)
    }

    /// https://stackoverflow.com/a/39385101/3164091
  }

  /// Creates and returns a new Bézier path object with the contents of a Core Graphics path.
  ///
  /// - Parameter cgPath: The Core Graphics path from which to obtain the path information
  convenience init(cgPath: CGPath) {
    self.init()
    addCGPath(cgPath)

    /// https://juripakaste.fi/nzbezierpath-cgpath/
    /// https://gist.github.com/lukaskubanek/1f3585314903dfc66fc7
  }

  /// Adds a Core Graphics path to the current Bézier path.
  ///
  /// - Parameter cgPath: The Core Graphics path to add.
  func addCGPath(_ cgPath: CGPath) {
    cgPath.applyWithBlock { (elementPointer: UnsafePointer<CGPathElement>) in
      let element = elementPointer.pointee
      let points = element.points
      switch element.type {
      case .moveToPoint:
        self.move(to: points.pointee)
      case .addLineToPoint:
        self.line(to: points.pointee)
      case .addQuadCurveToPoint:
        let control = points.pointee
        let target = points.successor().pointee
        self.addQuadCurve(to: target, controlPoint: control)

      // use cubic curve:
      //
      // let qp0 = self.currentPoint
      // let qp1 = points.pointee
      // let qp2 = points.successor().pointee
      // let m = 2.0 / 3.0
      // let cp1 = NSPoint(
      //   x: qp0.x + ((qp1.x - qp0.x) * m),
      //   y: qp0.y + ((qp1.y - qp0.y) * m)
      // )
      // let cp2 = NSPoint(
      //   x: qp2.x + ((qp1.x - qp2.x) * m),
      //   y: qp2.y + ((qp1.y - qp2.y) * m)
      // )
      // self.curve(to: qp2, controlPoint1: cp1, controlPoint2: cp2)
      case .addCurveToPoint:
        let control1 = points.pointee
        let control2 = points.advanced(by: 1).pointee
        let target = points.advanced(by: 2).pointee
        self.curve(to: target, controlPoint1: control1, controlPoint2: control2)
      case .closeSubpath:
        self.close()
      @unknown default:
        ComposeUI.assertFailure("Unknown CGPath element type: \(element.type)")
      }
    }

    // Documentation of `applyWithBlock(_:)`
    // https://stackoverflow.com/a/53282221/3164091
  }

  // MARK: - Testing

  #if DEBUG

  var test: Test { Test(host: self) }

  class Test {

    private let host: NSBezierPath

    fileprivate init(host: NSBezierPath) {
      ComposeUI.assert(Thread.isRunningXCTest, "test namespace should only be used in test target.")
      self.host = host
    }

    func addQuadCurve_below_macOS14(to point: CGPoint, controlPoint: CGPoint) {
      host.addQuadCurve_below_macOS14(to: point, controlPoint: controlPoint)
    }
  }

  #endif
}

#endif
