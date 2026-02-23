//
//  FrameNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/7/25.
//

import XCTest

@testable import ComposeUI

class FrameNodeTests: XCTestCase {

    // MARK: - FrameSize Tests

    func test_frameSize_equality() throws {
        XCTAssertEqual(FrameSize.fixed(10), FrameSize.fixed(10))
        XCTAssertNotEqual(FrameSize.fixed(10), FrameSize.fixed(20))
        XCTAssertEqual(FrameSize.flexible, FrameSize.flexible)
        XCTAssertEqual(FrameSize.intrinsic, FrameSize.intrinsic)
        XCTAssertNotEqual(FrameSize.fixed(10), FrameSize.flexible)
        XCTAssertNotEqual(FrameSize.fixed(10), FrameSize.intrinsic)
        XCTAssertNotEqual(FrameSize.flexible, FrameSize.intrinsic)
    }

    // MARK: - Layout Tests

    func test_layout_fixed_fixed() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).frame(width: .fixed(50), height: .fixed(30))

        let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(50), height: .fixed(30)))
        XCTAssertEqual(node.size, CGSize(width: 50, height: 30))
    }

    func test_layout_fixed_flexible() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).frame(width: .fixed(50), height: .flexible)

        let sizing = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(50), height: .flexible))
        XCTAssertEqual(node.size, CGSize(width: 50, height: 80))
    }

    func test_layout_fixed_intrinsic() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)

        var node = FixedSizeNode(size: CGSize(width: 60, height: 40))
            .frame(width: .fixed(50), height: .intrinsic)
        let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(50), height: .fixed(40)))
        XCTAssertEqual(node.size, CGSize(width: 50, height: 40))
    }

    func test_layout_flexible_fixed() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).frame(width: .flexible, height: .fixed(30))

        let sizing = node.layout(containerSize: CGSize(width: 80, height: 100), context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(30)))
        XCTAssertEqual(node.size, CGSize(width: 80, height: 30))
    }

    func test_layout_flexible_flexible() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).frame(width: .flexible, height: .flexible)

        let sizing = node.layout(containerSize: CGSize(width: 80, height: 60), context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
        XCTAssertEqual(node.size, CGSize(width: 80, height: 60))
    }

    func test_layout_flexible_intrinsic() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 60, height: 40)).frame(width: .flexible, height: .intrinsic)
        let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(40)))
        XCTAssertEqual(node.size, CGSize(width: 100, height: 40))
    }

    func test_layout_intrinsic_fixed() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 60, height: 40)).frame(width: .intrinsic, height: .fixed(50))
        let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(60), height: .fixed(50)))
        XCTAssertEqual(node.size, CGSize(width: 60, height: 50))
    }

    func test_layout_intrinsic_flexible() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 60, height: 40)).frame(width: .intrinsic, height: .flexible)
        let sizing = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(60), height: .flexible))
        XCTAssertEqual(node.size, CGSize(width: 60, height: 80))
    }

    func test_layout_intrinsic_intrinsic() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 60, height: 40)).frame(width: .intrinsic, height: .intrinsic)
        let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(60), height: .fixed(40)))
        XCTAssertEqual(node.size, CGSize(width: 60, height: 40))
    }

    // MARK: - RenderableItems Tests

    func test_renderableItems_center_alignment() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: 40, height: 30, alignment: .center)
        _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 80))
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.id.id, "F|FixedSizeNode")
        XCTAssertEqual(item.frame, CGRect(x: 15, y: 5, width: 10, height: 20))
    }

    func test_renderableItems_topLeft_alignment() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: 40, height: 30, alignment: .topLeft)
        _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 80))
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.id.id, "F|FixedSizeNode")
        XCTAssertEqual(item.frame, CGRect(x: 0, y: 0, width: 10, height: 20))
    }

    func test_renderableItems_bottomRight_alignment() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: 40, height: 30, alignment: .bottomRight)
        _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 80))
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.id.id, "F|FixedSizeNode")
        XCTAssertEqual(item.frame, CGRect(x: 30, y: 10, width: 10, height: 20))
    }

    // MARK: - Frame Modifier Tests

    func test_frame_frameSize_frameSize() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: .fixed(50), height: .flexible)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(node.size, CGSize(width: 50, height: 100))
    }

    func test_frame_cgFloat_frameSize() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: 50, height: .flexible)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(node.size, CGSize(width: 50, height: 100))
    }

    func test_frame_frameSize_cgFloat() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: .fixed(50), height: 30)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(node.size, CGSize(width: 50, height: 30))
    }

    func test_frame_cgFloat_cgFloat() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).frame(width: 50, height: 30)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(node.size, CGSize(width: 50, height: 30))
    }

    func test_frame_cgSize() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).frame(CGSize(width: 60, height: 40))
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(node.size, CGSize(width: 60, height: 40))
    }

    func test_frame_cgFloat_square() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).frame(50)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(node.size, CGSize(width: 50, height: 50))
    }

    func test_frame_frameSize_intrinsic_optimization() throws {
        let baseNode = ColorNode(.red)
        let framedNode = baseNode.frame(.intrinsic)

        // should return the original node when both dimensions are intrinsic
        XCTAssertFalse(String(describing: framedNode).contains("FrameNode"))
    }

    func test_frame_frameSize_non_intrinsic() throws {
        let baseNode = ColorNode(.red)
        let framedNode = baseNode.frame(.fixed(50))

        // should create a FrameNode when not both intrinsic
        XCTAssertTrue(String(describing: framedNode).contains("FrameNode"))
    }

    func test_width_modifier() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).width(60)
        _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

        XCTAssertEqual(node.size, CGSize(width: 60, height: 80))
    }

    func test_height_modifier() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red).height(40)
        _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

        XCTAssertEqual(node.size, CGSize(width: 100, height: 40))
    }

    func test_alignment_modifier() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).alignment(.topRight)
        _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 80))
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.frame, CGRect(x: 90, y: 0, width: 10, height: 20))
    }

    // MARK: - Complex Tests

    func test_frame_with_child_larger_than_frame() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)

        var node = FixedSizeNode(size: CGSize(width: 80, height: 60)).frame(width: 40, height: 30, alignment: .center)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.frame, CGRect(x: -20, y: -15, width: 80, height: 60))
    }

    func test_multiple_frame_modifiers() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red)
            .frame(width: 60, height: 40)
            .frame(width: 80, height: 50, alignment: .topLeft)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        XCTAssertEqual(node.size, CGSize(width: 80, height: 50)) // outer frame wins

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.id.id, "F|F|C") // Multiple frame node IDs
    }
}

private struct FixedSizeNode: ComposeNode {

    var id: ComposeNodeId = .custom("FixedSizeNode")

    let size: CGSize

    init(size: CGSize) {
        self.size = size
    }

    func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
        return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    }

    func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
        let layerItem = LayerItem<CALayer>(
            id: id,
            frame: CGRect(origin: .zero, size: size),
            make: { _ in CALayer() },
            update: { _, _ in }
        )
        return [layerItem.eraseToRenderableItem()]
    }
}
