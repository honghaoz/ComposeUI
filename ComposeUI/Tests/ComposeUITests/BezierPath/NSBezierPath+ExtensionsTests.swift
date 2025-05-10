//
//  NSBezierPath+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/9/24.
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

import ChouTiTest

@testable import ComposeUI

class NSBezierPath_ExtensionsTests: XCTestCase {

  func test_reversing() {
    let path = BezierPath()
    path.move(to: .zero)
    path.addLine(to: CGPoint(x: 1, y: 1))
    path.addCurve(to: CGPoint(x: 0, y: 0), controlPoint1: CGPoint(x: 1, y: 0.5), controlPoint2: CGPoint(x: 0.5, y: 1))
    let reversedPath = path.reversing()

    let memoryAddressString = memoryAddressString(reversedPath)

    #if canImport(AppKit)
    expect(String(describing: reversedPath)) ==
      """
      Path <\(memoryAddressString)>
        Bounds: {{0, 0}, {1, 1}}
        Control point bounds: {{0, 0}, {1, 1}}
          0.000000 0.000000 moveto
          0.500000 1.000000 1.000000 0.500000 1.000000 1.000000 curveto
          0.000000 0.000000 lineto
      """
    #endif

    #if canImport(UIKit)
    expect(String(describing: reversedPath)) ==
      """
      <UIBezierPath: \(memoryAddressString); <MoveTo {0, 0}>,
       <CurveTo {1, 1} {0.5, 1} {1, 0.5}>,
       <LineTo {0, 0}>
      """
    #endif
  }

  func test_addLine() {
    let path = BezierPath()
    path.move(to: .zero)
    path.addLine(to: CGPoint(x: 1, y: 1))
    path.addLine(to: CGPoint(x: 2, y: 2))
    expect(path.currentPoint) == CGPoint(x: 2, y: 2)

    let memoryAddressString = memoryAddressString(path)

    #if canImport(AppKit)
    expect(String(describing: path)) ==
      """
      Path <\(memoryAddressString)>
        Bounds: {{0, 0}, {2, 2}}
        Control point bounds: {{0, 0}, {2, 2}}
          0.000000 0.000000 moveto
          1.000000 1.000000 lineto
          2.000000 2.000000 lineto
      """
    #endif

    #if canImport(UIKit)
    expect(String(describing: path)) ==
      """
      <UIBezierPath: \(memoryAddressString); <MoveTo {0, 0}>,
       <LineTo {1, 1}>,
       <LineTo {2, 2}>
      """
    #endif
  }

  func test_addCurve() {
    let path = BezierPath()
    path.move(to: .zero)
    path.addCurve(to: CGPoint(x: 1, y: 1), controlPoint1: CGPoint(x: 0.5, y: 0), controlPoint2: CGPoint(x: 1, y: 0.5))
    expect(path.currentPoint) == CGPoint(x: 1, y: 1)

    let memoryAddressString = memoryAddressString(path)

    #if canImport(AppKit)
    expect(String(describing: path)) ==
      """
      Path <\(memoryAddressString)>
        Bounds: {{0, 0}, {1, 1}}
        Control point bounds: {{0, 0}, {1, 1}}
          0.000000 0.000000 moveto
          0.500000 0.000000 1.000000 0.500000 1.000000 1.000000 curveto
      """
    #endif

    #if canImport(UIKit)
    expect(String(describing: path)) ==
      """
      <UIBezierPath: \(memoryAddressString); <MoveTo {0, 0}>,
       <CurveTo {1, 1} {0.5, 0} {1, 0.5}>
      """
    #endif
  }

  func test_addQuadCurve() {
    // Test for macOS 14+
    do {
      let path = BezierPath()
      let memoryAddressString = memoryAddressString(path)
      path.move(to: .zero)
      path.addQuadCurve(to: CGPoint(x: 1, y: 1), controlPoint: CGPoint(x: 0.5, y: 0))
      expect(path.currentPoint) == CGPoint(x: 1, y: 1)

      #if canImport(AppKit)
      expect(String(describing: path)) ==
        """
        Path <\(memoryAddressString)>
          Bounds: {{0, 0}, {1, 1}}
          Control point bounds: {{0, 0}, {1, 1}}
            0.000000 0.000000 moveto
            0.500000 0.000000 1.000000 1.000000 quadcurveto
        """
      #endif

      #if canImport(UIKit)
      expect(String(describing: path)) ==
        """
        <UIBezierPath: \(memoryAddressString); <MoveTo {0, 0}>,
         <QuadCurveTo {1, 1} - {0.5, 0}>
        """
      #endif
    }

    #if canImport(AppKit)
    // Test for macOS 13-
    do {
      let path = BezierPath()
      let memoryAddressString = memoryAddressString(path)
      path.move(to: .zero)
      path.test.addQuadCurve_below_macOS14(to: CGPoint(x: 1, y: 1), controlPoint: CGPoint(x: 0.5, y: 0))
      expect(path.currentPoint) == CGPoint(x: 1, y: 1)

      expect(String(describing: path)) ==
        """
        Path <\(memoryAddressString)>
          Bounds: {{0, 0}, {1, 1}}
          Control point bounds: {{0, 0}, {1, 1}}
            0.000000 0.000000 moveto
            0.333333 0.000000 0.666667 0.333333 1.000000 1.000000 curveto
        """
    }
    #endif
  }

  func test_cgPath() {
    let path = BezierPath()
    path.move(to: .zero)
    path.addLine(to: CGPoint(x: 1, y: 1))
    path.addLine(to: CGPoint(x: 1, y: 2))
    path.addCurve(to: CGPoint(x: 10, y: 0), controlPoint1: CGPoint(x: 1, y: 1.5), controlPoint2: CGPoint(x: 0.5, y: 2))
    path.addQuadCurve(to: CGPoint(x: 10, y: 10), controlPoint: CGPoint(x: 0.5, y: 1))
    path.close()

    var cgPath = path.cgPath
    let cgPathMemoryAddressString = memoryAddressString(cgPath)

    #if canImport(AppKit)
    expect(String(describing: cgPath)) == "Path \(cgPathMemoryAddressString):\n  moveto (0, 0)\n    lineto (1, 1)\n    lineto (1, 2)\n    curveto (1, 1.5) (0.5, 2) (10, 0)\n    quadto (0.5, 1) (10, 10)\n    closepath\n  moveto (0, 0)\n"
    #endif
    #if canImport(UIKit)
    expect(String(describing: cgPath)) == "Path \(cgPathMemoryAddressString):\n  moveto (0, 0)\n    lineto (1, 1)\n    lineto (1, 2)\n    curveto (1, 1.5) (0.5, 2) (10, 0)\n    quadto (0.5, 1) (10, 10)\n    closepath\n"
    #endif

    let newCGPath = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil)
    let newCGPathMemoryAddressString = memoryAddressString(newCGPath)
    expect(String(describing: newCGPath)) == "Path \(newCGPathMemoryAddressString):\n  moveto (0, 0)\n    lineto (10, 0)\n    lineto (10, 10)\n    lineto (0, 10)\n    closepath\n"

    path.cgPath = newCGPath
    cgPath = path.cgPath
    let pathCGPathMemoryAddressString = memoryAddressString(cgPath)

    #if canImport(AppKit)
    if #available(macOS 14.0, *) {
      expect(String(describing: cgPath)) == "Path \(pathCGPathMemoryAddressString):\n  moveto (0, 0)\n    lineto (10, 0)\n    lineto (10, 10)\n    lineto (0, 10)\n    closepath\n"
    } else {
      expect(String(describing: cgPath)) == "Path \(pathCGPathMemoryAddressString):\n  moveto (0, 0)\n    lineto (10, 0)\n    lineto (10, 10)\n    lineto (0, 10)\n    closepath\n  moveto (0, 0)\n"
    }
    #endif
    #if canImport(UIKit)
    expect(String(describing: cgPath)) == "Path \(pathCGPathMemoryAddressString):\n  moveto (0, 0)\n    lineto (10, 0)\n    lineto (10, 10)\n    lineto (0, 10)\n    closepath\n"
    #endif
  }

  func test_init_cgPath() {
    let cgPath = CGMutablePath()
    cgPath.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
    cgPath.addQuadCurve(to: CGPoint(x: 10, y: 5), control: CGPoint(x: 5, y: 5))
    cgPath.addCurve(to: CGPoint(x: 5, y: 5), control1: CGPoint(x: 7.5, y: 0), control2: CGPoint(x: 2.5, y: 10))
    cgPath.closeSubpath()

    let path = BezierPath(cgPath: cgPath)

    let cgPathMemoryAddressString = memoryAddressString(cgPath)
    let pathMemoryAddressString = memoryAddressString(path)

    expect(String(describing: cgPath)) == "Path \(cgPathMemoryAddressString):\n  moveto (0, 0)\n    lineto (10, 0)\n    lineto (10, 10)\n    lineto (0, 10)\n    closepath\n    quadto (5, 5) (10, 5)\n    curveto (7.5, 0) (2.5, 10) (5, 5)\n    closepath\n"

    #if canImport(AppKit)
    expect(String(describing: path)) ==
      """
      Path <\(pathMemoryAddressString)>
        Bounds: {{0, 0}, {10, 10}}
        Control point bounds: {{0, 0}, {10, 10}}
          0.000000 0.000000 moveto
          10.000000 0.000000 lineto
          10.000000 10.000000 lineto
          0.000000 10.000000 lineto
          closepath
          0.000000 0.000000 moveto
          5.000000 5.000000 10.000000 5.000000 quadcurveto
          7.500000 0.000000 2.500000 10.000000 5.000000 5.000000 curveto
          closepath
          0.000000 0.000000 moveto
      """
    #endif

    #if canImport(UIKit)
    expect(String(describing: path)) ==
      """
      <UIBezierPath: \(pathMemoryAddressString); <MoveTo {0, 0}>,
       <LineTo {10, 0}>,
       <LineTo {10, 10}>,
       <LineTo {0, 10}>,
       <Close>,
       <QuadCurveTo {10, 5} - {5, 5}>,
       <CurveTo {5, 5} {7.5, 0} {2.5, 10}>,
       <Close>
      """
    #endif
  }
}
