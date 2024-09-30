//
//  CGRect+Extensions.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

extension CGRect {

  func actuallyIntersects(_ other: CGRect) -> Bool {
    let intersection = intersection(other)
    return !intersection.isNull && !intersection.isEmpty
  }

  func translate(_ point: CGPoint) -> CGRect {
    CGRect(origin: CGPoint(x: origin.x + point.x, y: origin.y + point.y), size: size)
  }
}

