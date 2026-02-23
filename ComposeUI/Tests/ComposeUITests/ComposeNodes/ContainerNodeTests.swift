//
//  ContainerNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/6/25.
//

import XCTest

import ComposeUI

class ContainerNodeTests: XCTestCase {

    func test() throws {
        let contentView = ComposeView {
            VerticalStack {
                LayerNode()
                LayerNode()
                LayerNode()
            }
            .mapChildren { node in
                node.frame(width: 10, height: 10)
            }
        }

        contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        contentView.refresh()

        let sublayers: [CALayer] = try XCTUnwrap(contentView.layer.sublayers)

        for layer in sublayers {
            XCTAssertEqual(layer.bounds.size, CGSize(width: 10, height: 10))
        }
    }
}
