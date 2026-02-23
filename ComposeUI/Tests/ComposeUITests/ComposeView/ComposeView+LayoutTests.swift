//
//  ComposeView+LayoutTests.swift
//  ComposéUI
//
//  Created by Honghao on 6/28/25.
//

import ChouTiTest

import ComposeUI

class ComposeView_LayoutTests: XCTestCase {

    func test_layoutBounds() throws {
        let view = ComposeView {
            try LabelNode("Test")
                .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        }

        #if canImport(AppKit)
        // force the view to have scrollers so that the layout bounds maybe affected
        view.hasHorizontalScroller = true
        view.hasVerticalScroller = true
        #endif

        // given a specified size
        view.frame.size = view.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )

        var layoutBounds: CGRect?
        view.debug { view, event in
            switch event {
            case .renderWillLayout(_, let bounds, _):
                layoutBounds = bounds
            default:
                break
            }
        }

        view.refresh()

        // the layout bounds should be the same as the view's bounds
        expect(layoutBounds) == view.bounds
        expect(view.showsHorizontalScrollIndicator) == false
        expect(view.showsVerticalScrollIndicator) == false
    }
}
