//
//  CALayer+DisableActions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/21.
//

import QuartzCore

// MARK: - Disable Actions

public extension CALayer {

    /// Execute the block with the specified actions disabled.
    ///
    /// `CALayer` has implicit animations for some properties, which is not desired in some cases.
    /// This method helps to disable the implicit animations for the given keys.
    ///
    /// Example:
    ///
    /// ```swift
    /// layer.disableActions(for: ["position", "bounds", "transform"]) {
    ///   layer.frame = newFrame
    ///   layer.transform = CATransform3DIdentity
    /// }
    /// ```
    ///
    /// If you need to disable all possible actions for the layer, use `disableActions(_:)`.
    ///
    /// - Parameters:
    ///   - keys: The keys to disable actions for.
    ///   - work: The block to execute.
    func disableActions(for keys: [String], _ work: () throws -> Void) rethrows {
        let originalActions = actions

        var disabledActions = [String: CAAction]()
        disabledActions.reserveCapacity(keys.count)

        for key in keys {
            disabledActions[key] = NSNull()
        }

        actions = disabledActions

        try work()

        actions = originalActions
    }
}
