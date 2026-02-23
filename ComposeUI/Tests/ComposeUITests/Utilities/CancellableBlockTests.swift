//
//  CancellableBlockTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
//

import ChouTiTest

@testable import ComposeUI

class CancellableBlockTests: XCTestCase {

  func test_notCancelled() {
    var isExecuted: Bool?
    var isCancelled: Bool?

    let block = CancellableBlock {
      isExecuted = true
    } cancel: {
      isCancelled = true
    }

    block.execute()

    expect(isExecuted) == true
    expect(isCancelled) == nil
  }

  func test_cancelled() {
    var isExecuted: Bool?
    var isCancelled: Bool?

    let block = CancellableBlock {
      isExecuted = true
    } cancel: {
      isCancelled = true
    }

    block.cancel()

    expect(isExecuted) == nil
    expect(isCancelled) == true

    block.execute()

    expect(isExecuted) == nil
    expect(isCancelled) == true
  }
}
