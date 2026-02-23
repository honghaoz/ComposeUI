//
//  RotationNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
//

import AppKit
import ComposeUI

extension ComposeNode {

    func rotate(by degrees: CGFloat) -> some ComposeNode {
        RotationNode(node: self, degrees: degrees)
    }
}

private struct RotationNode<Node: ComposeNode>: ComposeNode {

    private var node: Node
    private let degrees: CGFloat

    fileprivate init(node: Node, degrees: CGFloat) {
        self.node = node
        self.degrees = degrees
    }

    // MARK: - ComposeNode

    var id: ComposeNodeId = ComposeNodeId.custom("rotation", isFixed: false)

    var size: CGSize { node.size }

    mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
        node.layout(containerSize: containerSize, context: context)
    }

    func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
        let childItems = node.renderableItems(in: visibleBounds)

        var mappedChildItems: [RenderableItem] = []
        mappedChildItems.reserveCapacity(childItems.count)

        for item in childItems {
            let mappedItem = ViewItem<RotationView>(
                id: id.join(with: item.id),
                frame: item.frame,
                make: { context in
                    let originalRenderable = item.make(context)
                    switch originalRenderable {
                    case .view(let view):
                        let rotationView = RotationView(contentView: view)
                        rotationView.frame = item.frame
                        return rotationView
                    case .layer(let layer):
                        let rotationView = RotationView(contentLayer: layer)
                        rotationView.frame = item.frame
                        return rotationView
                    }
                },
                update: { view, context in
                    view.degrees = degrees
                    switch view.content {
                    case .view(let view):
                        item.update(.view(view), context)
                    case .layer(let layer):
                        item.update(.layer(layer), context)
                    }
                }
            )
            mappedChildItems.append(mappedItem.eraseToRenderableItem())
        }

        return mappedChildItems
    }
}
