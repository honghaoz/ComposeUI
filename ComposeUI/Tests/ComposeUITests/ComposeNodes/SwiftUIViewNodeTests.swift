//
//  SwiftUIViewNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/6/25.
//

import XCTest

@testable import ComposeUI
import SwiftUI

class SwiftUIViewNodeTests: XCTestCase {

    func test() {
        var view1: SwiftUIHostingView<AnyView>?
        var view2: MutableSwiftUIHostingView?
        let contentView = ComposeView {
            // static
            SwiftUIViewNode(
                id: "text",
                Text("Hello, World!")
            )
            .onInsert { renderable, _ in
                view1 = renderable.view as? SwiftUIHostingView<AnyView>
            }

            // dynamic
            SwiftUIViewNode {
                Text("Hello, World!")
            }
            .onInsert { renderable, _ in
                view2 = renderable.view as? MutableSwiftUIHostingView
            }
        }

        contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

        contentView.refresh()

        XCTAssertEqual(view1?.bounds.size, CGSize(width: 100, height: 25))
        XCTAssertEqual(view1?.isUserInteractionEnabled, true)
        XCTAssertEqual(view2?.bounds.size, CGSize(width: 100, height: 25))
        XCTAssertEqual(view2?.isUserInteractionEnabled, true)
    }

    func test_conditional_update() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = SwiftUIViewNode { Text("Hello, World!") }
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
        let items = node.renderableItems(in: visibleBounds)
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.id.id, "SUI")
        XCTAssertEqual(item.frame, CGRect(x: 0, y: 0, width: 100, height: 100))

        // normal update
        do {
            let contentView = ComposeView()
            let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let view = try XCTUnwrap(renderable.view as? MutableSwiftUIHostingView)
            XCTAssertTrue("\(view.content)".contains("Hello, World"))
        }

        // conditional update
        do {
            let contentView = ComposeView()
            let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

            // scroll doesn't trigger update
            do {
                let context = RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
                item.update(renderable, context)
                let view = try XCTUnwrap(renderable.view as? MutableSwiftUIHostingView)
                XCTAssertEqual("\(view.content)", "AnyView(EmptyView())") // doesn't update
            }

            // bounds change triggers update
            do {
                let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
                item.update(renderable, context)
                let view = try XCTUnwrap(renderable.view as? MutableSwiftUIHostingView)
                XCTAssertTrue("\(view.content)".contains("Hello, World"))
            }
        }
    }

    func test_static_fixedWidth_fixedHeight() {
        var view: SwiftUIHostingView<AnyView>?
        let contentView = ComposeView {
            // static
            SwiftUIViewNode(
                id: "text",
                SwiftUI.Color.black
                    .frame(width: 80, height: 50)
            )
            .fixedSize(width: true, height: true)
            .onInsert { renderable, _ in
                view = renderable.view as? SwiftUIHostingView<AnyView>
            }
        }

        contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        contentView.refresh()

        XCTAssertEqual(view?.bounds.size, CGSize(width: 80, height: 50))
    }

    func test_static_fixedWidth_flexibleHeight() {
        var view: SwiftUIHostingView<AnyView>?
        let contentView = ComposeView {
            // static
            SwiftUIViewNode(
                id: "text",
                SwiftUI.Color.black
                    .frame(width: 80, height: 50)
            )
            .fixedSize(width: true, height: false)
            .onInsert { renderable, _ in
                view = renderable.view as? SwiftUIHostingView<AnyView>
            }
        }

        contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        contentView.refresh()

        XCTAssertEqual(view?.bounds.size, CGSize(width: 80, height: 100))
    }

    func test_static_flexibleWidth_fixedHeight() {
        var view: SwiftUIHostingView<AnyView>?
        let contentView = ComposeView {
            // static
            SwiftUIViewNode(
                id: "text",
                SwiftUI.Color.black
                    .frame(width: 80, height: 50)
            )
            .fixedSize(width: false, height: true)
            .onInsert { renderable, _ in
                view = renderable.view as? SwiftUIHostingView<AnyView>
            }
        }

        contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        contentView.refresh()

        XCTAssertEqual(view?.bounds.size, CGSize(width: 100, height: 50))
    }

    func test_static_flexibleWidth_flexibleHeight() {
        var view: SwiftUIHostingView<AnyView>?
        let contentView = ComposeView {
            // static
            SwiftUIViewNode(
                id: "text",
                SwiftUI.Color.black
                    .frame(width: 80, height: 50)
            )
            .fixedSize(width: false, height: false)
            .onInsert { renderable, _ in
                view = renderable.view as? SwiftUIHostingView<AnyView>
            }
        }

        contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        contentView.refresh()

        XCTAssertEqual(view?.bounds.size, CGSize(width: 100, height: 100))
    }

    func test_view_outOfBounds() {
        var view: SwiftUIHostingView<AnyView>?
        let contentView = ComposeView {
            VerticalStack {
                SpacerNode(width: 0, height: 100)
                // static
                SwiftUIViewNode(
                    id: "text",
                    SwiftUI.Color.black
                        .frame(width: 80, height: 50)
                )
                .fixedSize(width: true, height: true)
                .onInsert { renderable, _ in
                    view = renderable.view as? SwiftUIHostingView<AnyView>
                }
            }
        }

        contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        contentView.refresh()

        XCTAssertNil(view)
    }
}
