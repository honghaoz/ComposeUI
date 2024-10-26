//
//  ComposeNode+If.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import Foundation

extension ComposeNode {

    /// If the condition is true, then return the result of the then closure.
    /// Otherwise, return the original node.
    ///
    /// - Parameters:
    ///   - condition: The condition to check.
    ///   - then: The closure to evaluate if the condition is true.
    /// - Returns: A new node with the result of the then closure if the condition is true, otherwise the original node.
    func `if`(_ condition: Bool, then: (Self) -> some ComposeNode) -> any ComposeNode {
        condition ? then(self) : self
    }

    /// If the condition is true, then return the result of the then closure.
    /// Otherwise, return the result of the else closure.
    ///
    /// - Parameters:
    ///   - condition: The condition to check.
    ///   - then: The closure to evaluate if the condition is true.
    ///   - else: The closure to evaluate if the condition is false.
    /// - Returns: A new node with the result of the then closure if the condition is true, otherwise the result of the else closure.
    func `if`(_ condition: Bool, then: (Self) -> some ComposeNode, else: (Self) -> some ComposeNode) -> any ComposeNode {
        condition ? then(self) : `else`(self)
    }
}
