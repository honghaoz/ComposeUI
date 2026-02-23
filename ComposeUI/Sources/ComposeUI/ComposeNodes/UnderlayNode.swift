//
//  UnderlayNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

/// A node that renders a node with an underlay node.
private struct UnderlayNode<Node: ComposeNode>: ComposeNode {

    private var node: Node
    private var underlayNode: any ComposeNode
    private let alignment: Layout.Alignment

    fileprivate init(node: Node,
                     underlayNode: any ComposeNode,
                     alignment: Layout.Alignment)
    {
        self.node = node
        self.underlayNode = underlayNode
        self.alignment = alignment
    }

    // MARK: - ComposeNode

    var id: ComposeNodeId = .standard(.underlay)

    var size: CGSize { node.size }

    mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
        let sizing = node.layout(containerSize: containerSize, context: context)
        _ = underlayNode.layout(containerSize: node.size, context: context)
        return sizing
    }

    func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
        // for the child node
        let childItems = node.renderableItems(in: visibleBounds)

        var mappedChildItems: [RenderableItem] = []
        mappedChildItems.reserveCapacity(childItems.count)

        for var item in childItems {
            item.id = id.join(with: item.id)
            mappedChildItems.append(item)
        }

        // for the underlay node
        let underlayFrame = Layout.position(rect: underlayNode.size, in: size, alignment: alignment)
        let boundsInUnderlay = visibleBounds.translate(-underlayFrame.origin)
        let underlayItems = underlayNode.renderableItems(in: boundsInUnderlay)

        var mappedUnderlayItems: [RenderableItem] = []
        mappedUnderlayItems.reserveCapacity(underlayItems.count)

        for var item in underlayItems {
            item.id = id.join(with: item.id, suffix: "U")
            item.frame = item.frame.translate(underlayFrame.origin)
            mappedUnderlayItems.append(item)
        }

        return mappedUnderlayItems + mappedChildItems
    }
}

// MARK: - ComposeNode

public extension ComposeNode {

    /// Add an underlay content to the node.
    ///
    /// - Parameters:
    ///   - alignment: The alignment of the underlay content.
    ///   - content: The content to render beneath the node.
    /// - Returns: A new node with the underlay applied.
    func underlay(alignment: Layout.Alignment = .center,
                  @ComposeContentBuilder content: () -> ComposeContent) -> some ComposeNode
    {
        UnderlayNode(
            node: self,
            underlayNode: content().asZStack(alignment: alignment),
            alignment: alignment
        )
    }

    /// Add a background content to the node.
    ///
    /// - Parameters:
    ///   - alignment: The alignment of the background content.
    ///   - content: The content to render as the background.
    /// - Returns: A new node with the background applied.
    @inlinable
    @inline(__always)
    func background(alignment: Layout.Alignment = .center,
                    @ComposeContentBuilder content: () -> ComposeContent) -> some ComposeNode
    {
        underlay(alignment: alignment, content: content)
    }

    /// Add a background node to the node.
    ///
    /// - Parameters:
    ///   - alignment: The alignment of the background node.
    ///   - content: The content to render as the background.
    /// - Returns: A new node with the background applied.
    @inlinable
    @inline(__always)
    func background(alignment: Layout.Alignment = .center, _ content: ComposeContent) -> some ComposeNode {
        underlay(alignment: alignment, content: { content })
    }
}
