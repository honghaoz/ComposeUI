//
//  CALayer+PrivateTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/21/25.
//

import QuartzCore

import ChouTiTest

@testable import ComposeUI

final class CALayerPrivateTests: XCTestCase {

    func test_invertsShadow() {
        let layer = CALayer()

        // default value
        expect(layer.invertsShadow) == false
        expect(layer.value(forKey: "invertsShadow") as? Bool) == false

        // set and get
        layer.invertsShadow = true
        expect(layer.invertsShadow) == true
        expect(layer.value(forKey: "invertsShadow") as? Bool) == true

        layer.invertsShadow = false
        expect(layer.invertsShadow) == false
        expect(layer.value(forKey: "invertsShadow") as? Bool) == false

        layer.invertsShadow = true
        expect(layer.invertsShadow) == true
        expect(layer.value(forKey: "invertsShadow") as? Bool) == true

        layer.setValue(false, forKey: "invertsShadow")
        expect(layer.invertsShadow) == false
        expect(layer.value(forKey: "invertsShadow") as? Bool) == false

        layer.setValue(true, forKey: "invertsShadow")
        expect(layer.invertsShadow) == true
        expect(layer.value(forKey: "invertsShadow") as? Bool) == true
    }
}
