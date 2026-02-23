//
//  CATransaction+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/21.
//

import QuartzCore

public extension CATransaction {

    /// Execute the block with Core Animation implicit animations disabled and return the result.
    ///
    /// If you need to disable implicit animations for a specific layer, prefer to use `CALayer.disableActions(for:_:)` instead.
    ///
    /// - Parameter work: The block to execute.
    /// - Returns: The result of the work block.
    @_spi(Private)
    @inlinable
    @inline(__always)
    static func disableAnimations<T>(_ work: () throws -> T) rethrows -> T {
        CATransaction.begin()
        defer {
            CATransaction.commit()
        }
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        return try work()
    }
}
