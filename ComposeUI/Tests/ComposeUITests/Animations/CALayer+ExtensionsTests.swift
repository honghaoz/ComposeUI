//
//  CALayer+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
//

import QuartzCore
import XCTest

@_spi(Private) @testable import ComposeUI

class CALayer_ExtensionsTests: XCTestCase {

    func test_backedView() {
        let view = UIView()
        let layer = view.layer
        XCTAssertTrue(layer.backedView === view)
    }

    func test_positionFromFrame() {
        let layer = CALayer()
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
        layer.frame = frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        XCTAssertEqual(layer.position(from: frame), CGPoint(x: 25, y: 40))
    }

    func test_bringSublayerToFront() {
        let layer = CALayer()
        let sublayer1 = CALayer()
        let sublayer2 = CALayer()
        layer.addSublayer(sublayer1)
        layer.addSublayer(sublayer2)
        layer.bringSublayerToFront(sublayer1)

        XCTAssertEqual(layer.sublayers, [sublayer2, sublayer1])

        let sublayer3 = CALayer()
        layer.bringSublayerToFront(sublayer3)
        XCTAssertEqual(layer.sublayers, [sublayer2, sublayer1])
    }

    func test_positionFromFrame_nonIdentityTransform() {
        let layer = CALayer()
        layer.transform = CATransform3DMakeRotation(CGFloat.pi / 4, 0, 0, 1)
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
        layer.frame = frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        var assertionCount = 0
        ComposeAssert.setTestAssertionFailureHandler { message, file, line, column in
            XCTAssertEqual(message, "CALayer.position(from:frame:) only works with identity transform.")
            assertionCount += 1
        }

        XCTAssertEqual(layer.position(from: frame), CGPoint(x: 25, y: 40))
        XCTAssertEqual(assertionCount, 1)

        ComposeAssert.resetTestAssertionFailureHandler()
    }
}
