//
//  ComposeLayoutTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/19/25.
//

import XCTest

import ComposeUI

class ComposeLayoutTests: XCTestCase {

    func testPosition_whenChildSizeIsSmallerThanContainer() {
        let smallSize = CGSize(width: 100, height: 200)
        let containerSize = CGSize(width: 300, height: 500)

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .center)
            XCTAssertEqual(frame, CGRect(x: 100, y: 150, width: 100, height: 200))
        }

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .left)
            XCTAssertEqual(frame, CGRect(x: 0, y: 150, width: 100, height: 200))
        }

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .right)
            XCTAssertEqual(frame, CGRect(x: 200, y: 150, width: 100, height: 200))
        }

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .top)
            XCTAssertEqual(frame, CGRect(x: 100, y: 0, width: 100, height: 200))
        }

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .bottom)
            XCTAssertEqual(frame, CGRect(x: 100, y: 300, width: 100, height: 200))
        }

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .topLeft)
            XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 100, height: 200))
        }

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .topRight)
            XCTAssertEqual(frame, CGRect(x: 200, y: 0, width: 100, height: 200))
        }

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .bottomLeft)
            XCTAssertEqual(frame, CGRect(x: 0, y: 300, width: 100, height: 200))
        }

        do {
            let frame = ComposeLayout.position(rect: smallSize, in: containerSize, alignment: .bottomRight)
            XCTAssertEqual(frame, CGRect(x: 200, y: 300, width: 100, height: 200))
        }
    }

    func testPosition_whenChildSizeIsBiggerThanContainer() {
        let childSize = CGSize(width: 500, height: 800)
        let containerSize = CGSize(width: 300, height: 500)

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .center)
            XCTAssertEqual(frame, CGRect(x: -100, y: -150, width: 500, height: 800))
        }

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .left)
            XCTAssertEqual(frame, CGRect(x: 0, y: -150, width: 500, height: 800))
        }

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .right)
            XCTAssertEqual(frame, CGRect(x: -200, y: -150, width: 500, height: 800))
        }

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .top)
            XCTAssertEqual(frame, CGRect(x: -100, y: 0, width: 500, height: 800))
        }

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .bottom)
            XCTAssertEqual(frame, CGRect(x: -100, y: -300, width: 500, height: 800))
        }

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .topLeft)
            XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 500, height: 800))
        }

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .topRight)
            XCTAssertEqual(frame, CGRect(x: -200, y: 0, width: 500, height: 800))
        }

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .bottomLeft)
            XCTAssertEqual(frame, CGRect(x: 0, y: -300, width: 500, height: 800))
        }

        do {
            let frame = ComposeLayout.position(rect: childSize, in: containerSize, alignment: .bottomRight)
            XCTAssertEqual(frame, CGRect(x: -200, y: -300, width: 500, height: 800))
        }
    }
}
