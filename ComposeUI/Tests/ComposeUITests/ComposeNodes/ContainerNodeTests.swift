//
//  ContainerNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/6/25.
//

import ChouTiTest

import ComposeUI

class ContainerNodeTests: XCTestCase {

    func test() throws {
        let contentView = ComposeView {
            VStack {
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

        #if canImport(AppKit)
        let sublayers: [CALayer] = try contentView.documentView.unwrap().layer.unwrap().sublayers.unwrap()
        #endif
        #if canImport(UIKit)
        let sublayers: [CALayer] = try contentView.layer.sublayers.unwrap()
        #endif

        for layer in sublayers {
            expect(layer.bounds.size) == CGSize(width: 10, height: 10)
        }
    }
}
