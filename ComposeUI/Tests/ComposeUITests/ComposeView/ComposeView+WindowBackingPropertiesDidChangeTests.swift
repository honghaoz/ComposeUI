//
//  ComposeView+WindowBackingPropertiesDidChangeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/8/25.
//

#if canImport(AppKit)

import ChouTiTest
import AppKit

@testable import ComposeUI

class ComposeView_WindowBackingPropertiesDidChangeTests: XCTestCase {

    func test_windowBackingPropertiesDidChange() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let window = TestWindowWithBackingScaleFactor()

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
        window.contentView?.addSubview(view)

        // initial render when added to window
        expect(renderCount).toEventually(beEqual(to: 1))
        expect(refreshCount) == 1
        expect(isAnimated) == false
        isAnimated = nil
        expect(view.contentScaleFactor) == window.backingScaleFactor

        // change backing scale factor - should trigger refresh
        window.backingScaleFactor = 3.0

        expect(renderCount).toEventually(beEqual(to: 2))
        expect(refreshCount) == 2
        expect(isAnimated) == false
        isAnimated = nil
        expect(view.contentScaleFactor) == 3.0

        // change backing scale factor again - should trigger another refresh
        window.backingScaleFactor = 1.0

        expect(renderCount).toEventually(beEqual(to: 3))
        expect(refreshCount) == 3
        expect(isAnimated) == false
        expect(view.contentScaleFactor) == 1.0
        isAnimated = nil
    }

    func test_windowBackingPropertiesDidChange_viewRemovedFromWindow() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let window = TestWindowWithBackingScaleFactor()

        var renderCount = 0
        var refreshCount = 0
        let view = ComposeView {
            renderCount += 1
            LayerNode()
                .onUpdate { _, _ in
                    refreshCount += 1
                }
        }

        view.frame = frame
        window.contentView?.addSubview(view)

        // initial render when added to window
        expect(renderCount).toEventually(beEqual(to: 1))
        expect(refreshCount) == 1

        // remove view from window
        view.removeFromSuperview()

        // change backing scale factor - should not trigger refresh since view is not in window
        window.backingScaleFactor = 3.0

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush any pending refreshes
        expect(renderCount) == 1 // no new render
        expect(refreshCount) == 1
    }
}

// MARK: - TestWindowWithBackingScaleFactor

private final class TestWindowWithBackingScaleFactor: NSWindow {

    private var _backingScaleFactor: CGFloat = 2.0
    override var backingScaleFactor: CGFloat {
        get {
            _backingScaleFactor
        }
        set {
            _backingScaleFactor = newValue
            NotificationCenter.default.post(name: NSWindow.didChangeBackingPropertiesNotification, object: self)
        }
    }

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        contentView?.wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
    }
}

#endif
