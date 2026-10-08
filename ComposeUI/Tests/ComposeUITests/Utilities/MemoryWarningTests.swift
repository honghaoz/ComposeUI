//
//  MemoryWarningTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/8/26.
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

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

@testable import ComposeUI

class MemoryWarningTests: XCTestCase {

  func test_handleMemoryWarning_runsEachHandler() {
    // given: two handlers added to run on memory warnings
    var firstCallCount = 0
    var secondCallCount = 0
    MemoryWarning.addHandler { firstCallCount += 1 }
    MemoryWarning.addHandler { secondCallCount += 1 }

    // when: handling a memory warning twice
    MemoryWarning.handleMemoryWarning()
    MemoryWarning.handleMemoryWarning()

    // then: each handler ran each time
    expect(firstCallCount) == 2
    expect(secondCallCount) == 2
  }

  #if canImport(UIKit)
  func test_memoryWarningNotification_runsTheHandlers() {
    // given: a handler added to run on memory warnings
    var callCount = 0
    MemoryWarning.addHandler { callCount += 1 }

    // when: the system sends a memory warning
    NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

    // then: the handler ran
    expect(callCount) == 1
  }
  #endif

  #if canImport(AppKit)
  func test_addHandler_listensToMemoryPressure() throws {
    // when: adding a handler
    MemoryWarning.addHandler {}

    // then: the system's memory pressure events are listened to, and their handler is `handleMemoryWarning()`. a test
    // can't send a real event, which takes `sudo memory_pressure -S -l warning`
    let source = try unwrap(MemoryWarning.memoryPressureSource)
    expect(source.isCancelled) == false
  }
  #endif
}
