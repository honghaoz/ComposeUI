//
//  CancellableBlock.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
//

import Foundation

/// A cancellable block that can be used to cancel a block execution.
final class CancellableBlock {

    private var isCancelled = false

    /// The block to be executed.
    private let workBlock: () -> Void

    /// The block to be executed when the cancellable block is cancelled.
    private let cancelBlock: (() -> Void)?

    /// Initializes a new cancellable block.
    ///
    /// - Parameters:
    ///   - block: The block to be executed.
    ///   - cancel: The block to be executed when the cancellable block is cancelled.
    init(block: @escaping () -> Void, cancel: (() -> Void)? = nil) {
        self.workBlock = block
        self.cancelBlock = cancel
    }

    /// Cancels the block execution.
    func cancel() {
        isCancelled = true
        cancelBlock?()
    }

    /// Executes the block if it is not cancelled.
    func execute() {
        if !isCancelled {
            workBlock()
        }
    }
}
