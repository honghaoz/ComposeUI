//
//  CGRect+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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
}
