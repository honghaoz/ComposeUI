//
//  ComposeNode+Transform.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 1/28/26.
//

import Foundation

public extension ComposeNode {

    /// Transform the current node into a new node.
    ///
    /// - Parameter transform: The closure transforming the current node into a new node.
    /// - Returns: A new node returned by the transform closure.
    func map(_ transform: (Self) -> any ComposeNode) -> any ComposeNode {
        transform(self)
    }

    /// Transform the current node into a new node of the same type.
    ///
    /// - Parameter transform: The closure transforming the current node into a new node of the same type.
    /// - Returns: A new node returned by the transform closure.
    func map(_ transform: (Self) -> Self) -> Self {
        transform(self)
    }
}
