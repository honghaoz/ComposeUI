//
//  CGPoint+Extensions.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

extension CGPoint {

  static prefix func - (point: CGPoint) -> CGPoint {
    CGPoint(x: -point.x, y: -point.y)
  }
}
