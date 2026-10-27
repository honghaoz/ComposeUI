//
//  UnfairLock.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/26/26.
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

import os

/// A lock for state that threads share, held only to read or change the state.
///
/// It keeps its `os_unfair_lock` at an address that it allocates, since the lock needs an address that doesn't change,
/// which a stored property doesn't have, and it can't be copied, since a copy would share and free that address.
struct UnfairLock: ~Copyable {

  private let lock: UnsafeMutablePointer<os_unfair_lock>

  /// Makes an unlocked lock.
  init() {
    lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    lock.initialize(to: os_unfair_lock())
  }

  deinit {
    lock.deinitialize(count: 1)
    lock.deallocate()
  }

  /// Runs a body while holding the lock.
  ///
  /// - Parameter body: The body, which mustn't take the lock again.
  /// - Returns: The body's result.
  func withLock<T>(_ body: () -> T) -> T {
    os_unfair_lock_lock(lock)
    defer {
      os_unfair_lock_unlock(lock)
    }
    return body()
  }
}
