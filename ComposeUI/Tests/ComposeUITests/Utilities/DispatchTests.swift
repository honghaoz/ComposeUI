//
//  DispatchTests.swift
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

import ChouTiTest

@testable import ComposeUI

class DispatchTests: XCTestCase {

  func test_asyncWithoutFlags_runsTheBlockLaterOnTheQueue() {
    // given: a suspended queue, which its blocks tell by a value set on it
    final class Run {
      var isOnQueue: Bool?
    }
    let queue = DispatchQueue(label: "io.chouti.composeui.DispatchTests")
    let key = DispatchSpecificKey<Bool>()
    queue.setSpecific(key: key, value: true)
    queue.suspend()
    let run = Run()

    // when: submitting a block without flags
    queue.asyncWithoutFlags {
      run.isOnQueue = DispatchQueue.getSpecific(key: key) ?? false
    }

    // then: the block hasn't run
    expect(run.isOnQueue) == nil

    // when: the queue resumes and runs its blocks
    queue.resume()
    queue.sync {}

    // then: the block ran on the queue
    expect(run.isOnQueue) == true
  }
}
