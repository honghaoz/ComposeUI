//
//  LayoutTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/19/25.
//

import ChouTiTest

import ComposeUI

class LayoutTests: XCTestCase {

  func testPosition_whenChildSizeIsSmallerThanContainer() {
    let smallSize = CGSize(width: 100, height: 200)
    let containerSize = CGSize(width: 300, height: 500)

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .center)
      expect(frame) == CGRect(x: 100, y: 150, width: 100, height: 200)
    }

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .left)
      expect(frame) == CGRect(x: 0, y: 150, width: 100, height: 200)
    }

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .right)
      expect(frame) == CGRect(x: 200, y: 150, width: 100, height: 200)
    }

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .top)
      expect(frame) == CGRect(x: 100, y: 0, width: 100, height: 200)
    }

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .bottom)
      expect(frame) == CGRect(x: 100, y: 300, width: 100, height: 200)
    }

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .topLeft)
      expect(frame) == CGRect(x: 0, y: 0, width: 100, height: 200)
    }

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .topRight)
      expect(frame) == CGRect(x: 200, y: 0, width: 100, height: 200)
    }

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .bottomLeft)
      expect(frame) == CGRect(x: 0, y: 300, width: 100, height: 200)
    }

    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .bottomRight)
      expect(frame) == CGRect(x: 200, y: 300, width: 100, height: 200)
    }
  }

  func testPosition_whenChildSizeIsBiggerThanContainer() {
    let childSize = CGSize(width: 500, height: 800)
    let containerSize = CGSize(width: 300, height: 500)

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .center)
      expect(frame) == CGRect(x: -100, y: -150, width: 500, height: 800)
    }

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .left)
      expect(frame) == CGRect(x: 0, y: -150, width: 500, height: 800)
    }

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .right)
      expect(frame) == CGRect(x: -200, y: -150, width: 500, height: 800)
    }

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .top)
      expect(frame) == CGRect(x: -100, y: 0, width: 500, height: 800)
    }

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .bottom)
      expect(frame) == CGRect(x: -100, y: -300, width: 500, height: 800)
    }

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .topLeft)
      expect(frame) == CGRect(x: 0, y: 0, width: 500, height: 800)
    }

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .topRight)
      expect(frame) == CGRect(x: -200, y: 0, width: 500, height: 800)
    }

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .bottomLeft)
      expect(frame) == CGRect(x: 0, y: -300, width: 500, height: 800)
    }

    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .bottomRight)
      expect(frame) == CGRect(x: -200, y: -300, width: 500, height: 800)
    }
  }
}
