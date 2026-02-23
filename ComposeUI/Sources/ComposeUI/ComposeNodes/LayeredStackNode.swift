//
//  LayeredStackNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

public typealias LayeredStack = LayeredStackNode

/// A node that stacks its children in z-axis.
///
/// The node's size is the maximum size of its children.
public struct LayeredStackNode: ComposeNode, ContainerNodeInternal {

    private let alignment: ComposeLayout.Alignment
    var childNodes: [any ComposeNode]

    public init(alignment: ComposeLayout.Alignment = .center, @ComposeContentBuilder content: () -> ComposeContent) {
        self.alignment = alignment
        self.childNodes = content().asNodes()
    }

    // MARK: - ComposeNode

    public var id: ComposeNodeId = .standard(.zStack)

    public private(set) var size: CGSize = .zero

    public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
        guard !childNodes.isEmpty else {
            size = .zero
            return ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
        }

        let childCount = childNodes.count

        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        var widthSizing: ComposeNodeSizing.Sizing = .fixed(0)
        var heightSizing: ComposeNodeSizing.Sizing = .fixed(0)

        for nodeIndex in 0 ..< childCount {
            let childSizing = childNodes[nodeIndex].layout(containerSize: containerSize, context: context)
            let childSize = childNodes[nodeIndex].size

            if childSize.width > maxWidth {
                maxWidth = childSize.width
            }
            if childSize.height > maxHeight {
                maxHeight = childSize.height
            }

            widthSizing = widthSizing.combine(with: childSizing.width, axis: .cross)
            heightSizing = heightSizing.combine(with: childSizing.height, axis: .cross)
        }

        size = CGSize(width: maxWidth, height: maxHeight)
        return ComposeNodeSizing(width: widthSizing, height: heightSizing)
    }

    public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
        var mappedChildItems: [RenderableItem] = []
        mappedChildItems.reserveCapacity(childNodes.count * 4) // use 4x capacity as a rough estimate for the number of items

        for i in 0 ..< childNodes.count {
            let node = childNodes[i]

            let childFrame = ComposeLayout.position(rect: node.size, in: size, alignment: alignment)
            let boundsInChild = visibleBounds.translate(-childFrame.origin)

            let childItems = node.renderableItems(in: boundsInChild)

            for var item in childItems {
                item.id = id.join(with: item.id, suffix: "\(i)")
                item.frame = item.frame.translate(childFrame.origin)
                mappedChildItems.append(item)
            }
        }

        return mappedChildItems
    }
}
