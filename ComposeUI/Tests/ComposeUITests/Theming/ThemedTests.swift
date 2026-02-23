//
//  ThemedTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import ChouTiTest

@testable import ComposeUI

class ThemedTests: XCTestCase {

  func test() {
    do {
      let themed = Themed(light: Color.red, dark: Color.blue)
      expect(themed.resolve(for: .light)) == Color.red
      expect(themed.resolve(for: .dark)) == Color.blue
    }

    do {
      let themed = Themed(Color.red)
      expect(themed.resolve(for: .light)) == Color.red
      expect(themed.resolve(for: .dark)) == Color.red
    }
  }

  func test_equal() {
    let themed1 = Themed(light: Color.red, dark: Color.blue)
    let themed2 = Themed(light: Color.red, dark: Color.blue)
    expect(themed1) == themed2
  }

  func test_hashable() {
    let themed1 = Themed(light: Color.red, dark: Color.blue)
    let themed2 = Themed(light: Color.red, dark: Color.blue)
    expect(themed1.hashValue) == themed2.hashValue
  }
}
