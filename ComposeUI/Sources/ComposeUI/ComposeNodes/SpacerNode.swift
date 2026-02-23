//
//  SpacerNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

public typealias Spacer = SpacerNode

/// A node that occupies the some space.
public struct SpacerNode: ComposeNode {

    private(set) var width: CGFloat?
    private(set) var height: CGFloat?

    /// Make a spacer with the given size.
    /// - Parameters:
    ///   - size: The size of the spacer. Pass `nil` to make the spacer flexible.
    @inlinable
    @inline(__always)
    public init(_ size: CGSize?) {
        self.init(width: size?.width, height: size?.height)
    }

    /// Make a spacer with the given size.
    /// - Parameters:
    ///   - size: The size of the spacer. Pass `nil` to make the spacer flexible.
    @inlinable
    @inline(__always)
    public init(_ size: CGFloat?) {
        self.init(width: size, height: size)
    }

    /// Make a spacer with the given size.
    /// - Parameters:
    ///   - width: The fixed width. If not specified, the width follows the container.
    ///   - height: The fixed height. If not specified, the height follows the container.
    public init(width: CGFloat? = nil, height: CGFloat? = nil) {
        self.width = width
        self.height = height
    }

    // MARK: - ComposeNode

    public var id: ComposeNodeId = .standard(.spacer)

    public private(set) var size: CGSize = .zero

    public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
        let sizing: ComposeNodeSizing

        switch (width, height) {
        case (.none, .none):
            self.size = containerSize
            sizing = ComposeNodeSizing(width: .flexible, height: .flexible)
        case (.some(let width), .none):
            self.size = CGSize(width: width, height: containerSize.height)
            sizing = ComposeNodeSizing(width: .fixed(width), height: .flexible)
        case (.none, .some(let height)):
            self.size = CGSize(width: containerSize.width, height: height)
            sizing = ComposeNodeSizing(width: .flexible, height: .fixed(height))
        case (.some(let width), .some(let height)):
            self.size = CGSize(width: width, height: height)
            sizing = ComposeNodeSizing(width: .fixed(width), height: .fixed(height))
        }

        return sizing
    }

    public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
        return []
    }

    // MARK: - Public

    /// Set the width of the spacer.
    /// - Parameter width: The width to set. Pass `nil` to make the spacer flexible in width.
    public func width(_ width: CGFloat?) -> SpacerNode {
        guard self.width != width else {
            return self
        }

        var copy = self
        copy.width = width

        return copy
    }

    /// Set the height of the spacer.
    /// - Parameter height: The height to set. Pass `nil` to make the spacer flexible in height.
    public func height(_ height: CGFloat?) -> SpacerNode {
        guard self.height != height else {
            return self
        }

        var copy = self
        copy.height = height

        return copy
    }
}
