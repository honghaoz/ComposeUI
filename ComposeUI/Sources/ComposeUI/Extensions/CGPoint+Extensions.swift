//
//  CGPoint+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

extension CGPoint {

    static prefix func - (point: CGPoint) -> CGPoint {
        CGPoint(x: -point.x, y: -point.y)
    }

    /// Get a vector from left to right.
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
}
