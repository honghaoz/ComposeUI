//
//  LayoutTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/19/25.
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

import ComposeUI

class LayoutTests: XCTestCase {

  func testPosition_whenChildSizeIsSmallerThanContainer() {
    // given: a child size smaller than the container
    let smallSize = CGSize(width: 100, height: 200)
    let containerSize = CGSize(width: 300, height: 500)

    // when: positioning with center alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .center)

      // then: the child is centered
      expect(frame) == CGRect(x: 100, y: 150, width: 100, height: 200)
    }

    // when: positioning with left alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .left)

      // then: the child is pinned to the left edge, vertically centered
      expect(frame) == CGRect(x: 0, y: 150, width: 100, height: 200)
    }

    // when: positioning with right alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .right)

      // then: the child is pinned to the right edge, vertically centered
      expect(frame) == CGRect(x: 200, y: 150, width: 100, height: 200)
    }

    // when: positioning with top alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .top)

      // then: the child is pinned to the top edge, horizontally centered
      expect(frame) == CGRect(x: 100, y: 0, width: 100, height: 200)
    }

    // when: positioning with bottom alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .bottom)

      // then: the child is pinned to the bottom edge, horizontally centered
      expect(frame) == CGRect(x: 100, y: 300, width: 100, height: 200)
    }

    // when: positioning with top left alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .topLeft)

      // then: the child is pinned to the top left corner
      expect(frame) == CGRect(x: 0, y: 0, width: 100, height: 200)
    }

    // when: positioning with top right alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .topRight)

      // then: the child is pinned to the top right corner
      expect(frame) == CGRect(x: 200, y: 0, width: 100, height: 200)
    }

    // when: positioning with bottom left alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .bottomLeft)

      // then: the child is pinned to the bottom left corner
      expect(frame) == CGRect(x: 0, y: 300, width: 100, height: 200)
    }

    // when: positioning with bottom right alignment
    do {
      let frame = Layout.position(rect: smallSize, in: containerSize, alignment: .bottomRight)

      // then: the child is pinned to the bottom right corner
      expect(frame) == CGRect(x: 200, y: 300, width: 100, height: 200)
    }
  }

  func testPosition_whenChildSizeIsBiggerThanContainer() {
    // given: a child size bigger than the container
    let childSize = CGSize(width: 500, height: 800)
    let containerSize = CGSize(width: 300, height: 500)

    // when: positioning with center alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .center)

      // then: the child is centered, overflowing the container
      expect(frame) == CGRect(x: -100, y: -150, width: 500, height: 800)
    }

    // when: positioning with left alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .left)

      // then: the child is pinned to the left edge, vertically centered
      expect(frame) == CGRect(x: 0, y: -150, width: 500, height: 800)
    }

    // when: positioning with right alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .right)

      // then: the child is pinned to the right edge, vertically centered
      expect(frame) == CGRect(x: -200, y: -150, width: 500, height: 800)
    }

    // when: positioning with top alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .top)

      // then: the child is pinned to the top edge, horizontally centered
      expect(frame) == CGRect(x: -100, y: 0, width: 500, height: 800)
    }

    // when: positioning with bottom alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .bottom)

      // then: the child is pinned to the bottom edge, horizontally centered
      expect(frame) == CGRect(x: -100, y: -300, width: 500, height: 800)
    }

    // when: positioning with top left alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .topLeft)

      // then: the child is pinned to the top left corner
      expect(frame) == CGRect(x: 0, y: 0, width: 500, height: 800)
    }

    // when: positioning with top right alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .topRight)

      // then: the child is pinned to the top right corner
      expect(frame) == CGRect(x: -200, y: 0, width: 500, height: 800)
    }

    // when: positioning with bottom left alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .bottomLeft)

      // then: the child is pinned to the bottom left corner
      expect(frame) == CGRect(x: 0, y: -300, width: 500, height: 800)
    }

    // when: positioning with bottom right alignment
    do {
      let frame = Layout.position(rect: childSize, in: containerSize, alignment: .bottomRight)

      // then: the child is pinned to the bottom right corner
      expect(frame) == CGRect(x: -200, y: -300, width: 500, height: 800)
    }
  }
}
