//
//  ComposeView+KeyWindowTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/30/25.
//

#if canImport(AppKit)
import ChouTiTest

import ComposeUI

class ComposeView_KeyWindowTests: XCTestCase {

    func test_keyWindowDidChange() throws {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let window = TestWindow()

        var renderCount = 0
        var refreshCount = 0
        var isAnimated: Bool?
        let view = ComposeView {
            renderCount += 1
            LayerNode()
                .animation(.linear())
                .onUpdate { _, context in
                    isAnimated = context.animationTiming != nil
                    refreshCount += 1
                }
        }

        view.frame = frame

        view.refresh()
        expect(renderCount) == 1 // initial render
        expect(refreshCount) == 1
        expect(isAnimated) == false
        isAnimated = nil

        window.contentView?.addSubview(view)

        window.makeKey()
        expect(renderCount).toEventually(beEqual(to: 2))
        expect(refreshCount) == 2
        expect(isAnimated) == false
        isAnimated = nil

        window.resignKey()
        expect(renderCount).toEventually(beEqual(to: 3))
        expect(refreshCount) == 3
        expect(isAnimated) == false
        isAnimated = nil

        window.makeKey()
        expect(renderCount).toEventually(beEqual(to: 4))
        expect(refreshCount) == 4
        expect(isAnimated) == false
        isAnimated = nil

        view.removeFromSuperview()

        window.resignKey()
        expect(renderCount) == 4
        expect(refreshCount) == 4
        expect(isAnimated) == nil
        isAnimated = nil

        window.makeKey()
        expect(renderCount) == 4
        expect(refreshCount) == 4
        expect(isAnimated) == nil
        isAnimated = nil
    }
}

#endif
