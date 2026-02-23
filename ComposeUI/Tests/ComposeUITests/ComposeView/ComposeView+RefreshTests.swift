//
//  ComposeView+RefreshTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/3/25.
//

import ChouTiTest

import ComposeUI
import ChouTi

class ComposeView_RefreshTests: XCTestCase {

    func test_refresh() {
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

        view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

        view.refresh()
        expect(renderCount) == 1
        expect(refreshCount) == 1
        expect(isAnimated) == false // initial render is always not animated
        isAnimated = nil

        view.refresh()
        expect(renderCount) == 2
        expect(refreshCount) == 2
        expect(isAnimated) == true
        isAnimated = nil

        view.refresh(animated: false)
        expect(renderCount) == 3
        expect(refreshCount) == 3
        expect(isAnimated) == false
        isAnimated = nil

        view.setNeedsRefresh(animated: true)
        expect(renderCount) == 3
        expect(refreshCount) == 3
        view.setNeedsRefresh()
        expect(renderCount) == 3
        expect(refreshCount) == 3
        view.setNeedsRefresh(animated: false)
        expect(renderCount) == 3
        expect(refreshCount) == 3

        expect(renderCount).toEventually(beEqual(to: 4))
        expect(refreshCount) == 4
        expect(isAnimated) == false // the refresh animation flag should be the last scheduled refresh
    }

    func test_setNeedsRefresh() {
        // given: a compose view
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

        view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

        // when: set needs refresh
        view.setNeedsRefresh()

        // then: expect a pending refresh is scheduled but the refresh is not performed immediately
        expect(DynamicLookup(view).property("pendingRefresh")) != nil
        expect(renderCount) == 0
        expect(refreshCount) == 0
        expect(isAnimated) == nil
        isAnimated = nil

        // wait for next run loop iteration
        wait(timeout: 0.01)

        // then: expect the refresh is performed
        expect(DynamicLookup(view).property("pendingRefresh")) == nil
        expect(renderCount) == 1
        expect(refreshCount) == 1
        expect(isAnimated) == false
        isAnimated = nil

        // when: set needs refresh again
        view.setNeedsRefresh()

        expect(DynamicLookup(view).property("pendingRefresh")) != nil
        expect(renderCount) == 1
        expect(refreshCount) == 1
        expect(isAnimated) == nil
        isAnimated = nil

        // when: refresh the view
        view.refresh()

        // then: expect the refresh is performed and the pending refresh is cancelled
        expect(DynamicLookup(view).property("pendingRefresh")) == nil
        expect(renderCount) == 2
        expect(refreshCount) == 2
        expect(isAnimated) == true
    }

    func test_subview_order() {
        // verify that the subviews are in the correct order after a refresh.

        let view1 = BaseView()
        let view2 = BaseView()
        let view3 = BaseView()

        let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))

        contentView.setContent {
            HStack {
                ViewNode(view1, update: { _, _ in })
                    .frame(width: 100, height: 100)
                ViewNode(view2, update: { _, _ in })
                    .frame(width: 100, height: 100)
                ViewNode(view3, update: { _, _ in })
                    .frame(width: 100, height: 100)
            }
        }
        contentView.refresh(animated: false)

        expect(contentView.contentView().subviews) == [view1, view2, view3]

        contentView.refresh(animated: false)

        expect(contentView.contentView().subviews) == [view1, view2, view3]

        // change the order of the views
        contentView.setContent {
            HStack {
                ViewNode(view3, update: { _, _ in })
                    .frame(width: 100, height: 100)
                ViewNode(view2, update: { _, _ in })
                    .frame(width: 100, height: 100)
            }
        }

        contentView.refresh(animated: false)

        expect(contentView.contentView().subviews) == [view3, view2]
    }
}
