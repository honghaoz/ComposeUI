//
//  SwiftUI.View+SizeThatFitsTests.swift
//  ComposéUI
//
//  Created by Honghao on 6/30/25.
//

import ChouTiTest

import SwiftUI
import ComposeUI

class SwiftUI_View_SizeThatFitsTests: XCTestCase {

  func test_sizeThatFits() {
    // when the view has a fixed size
    do {
      let view = SwiftUI.Color.black.frame(width: 80, height: 50)

      // when proposing size is larger
      expect(
        view.sizeThatFits(CGSize(width: 100, height: 100))
      ) == CGSize(width: 80, height: 50)

      // when proposing size is smaller
      expect(
        view.sizeThatFits(CGSize(width: 50, height: 40))
      ) == CGSize(width: 80, height: 50)
    }

    // when the view has a flexible size
    do {
      let view = SwiftUI.Color.black

      // when proposing size is larger
      expect(
        view.sizeThatFits(CGSize(width: 100, height: 100))
      ) == CGSize(width: 100, height: 100)

      // when proposing size is smaller
      expect(
        view.sizeThatFits(CGSize(width: 50, height: 50))
      ) == CGSize(width: 50, height: 50)
    }
  }
}
