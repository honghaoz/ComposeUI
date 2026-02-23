//
//  Layout.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

public enum Layout {

    /// The horizontal alignment of a subcomponent relative to its parent.
    public enum HorizontalAlignment: Hashable, Sendable, CaseIterable {
        case center
        case left
        case right
    }

    /// The vertical alignment of a subcomponent relative to its parent.
    public enum VerticalAlignment: Hashable, Sendable, CaseIterable {
        case center
        case top
        case bottom
    }

    /// The alignment of a subcomponent relative to its parent.
    public enum Alignment: Hashable, Sendable, CaseIterable {
        case center
        case left
        case right
        case top
        case bottom
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    /// Get the frame of a child rectangle positioned within a container rectangle based on a specified alignment.
    ///
    /// - Parameters:
    ///   - size: The size of the child rectangle.
    ///   - containerSize: The size of the container rectangle in which the child will be positioned.
    ///   - alignment: The alignment of the rectangle.
    /// - Returns: A `CGRect` representing the frame of the child rectangle positioned within the container according to the specified alignment.
    public static func position(rect size: CGSize, in containerSize: CGSize, alignment: Layout.Alignment) -> CGRect {
        CGRect(
            origin: {
                switch alignment {
                case .center:
                    return CGPoint(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2)
                case .left:
                    return CGPoint(x: 0, y: (containerSize.height - size.height) / 2)
                case .right:
                    return CGPoint(x: containerSize.width - size.width, y: (containerSize.height - size.height) / 2)
                case .top:
                    return CGPoint(x: (containerSize.width - size.width) / 2, y: 0)
                case .bottom:
                    return CGPoint(x: (containerSize.width - size.width) / 2, y: containerSize.height - size.height)
                case .topLeft:
                    return .zero
                case .topRight:
                    return CGPoint(x: containerSize.width - size.width, y: 0)
                case .bottomLeft:
                    return CGPoint(x: 0, y: containerSize.height - size.height)
                case .bottomRight:
                    return CGPoint(x: containerSize.width - size.width, y: containerSize.height - size.height)
                }
            }(),
            size: size
        )
    }
}
