//
//  CancellableBlock.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
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
