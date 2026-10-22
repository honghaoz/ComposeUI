//
//  NewThread.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/20/26.
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

/// Runs a block on a new thread, and returns its result once the thread exits.
///
/// The thread starts without any thread-local state, and the call returns after the thread's thread-local destructors
/// run, so a test can check what a thread releases when it exits.
///
/// - Parameter body: The block.
/// - Returns: The block's result.
func onNewThread<T>(_ body: @escaping () -> T) -> T {
  var result: T?
  let thread = ThreadBody { result = body() }
  var handle: pthread_t?
  let status = pthread_create(&handle, nil, { pointer in
    Unmanaged<ThreadBody>.fromOpaque(pointer).takeRetainedValue().run()
    return nil
  }, Unmanaged.passRetained(thread).toOpaque())
  precondition(status == 0, "a thread must be created")
  pthread_join(handle!, nil) // swiftlint:disable:this force_unwrapping
  return result! // swiftlint:disable:this force_unwrapping
}

/// The block that a new thread runs.
private final class ThreadBody {

  let run: () -> Void

  init(_ run: @escaping () -> Void) {
    self.run = run
  }
}
