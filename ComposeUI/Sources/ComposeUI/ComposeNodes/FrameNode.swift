//
//  FrameNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

public enum FrameSize: Hashable {

  case fixed(CGFloat)

  case flexible

  case intrinsic
}

extension Compose {
  
  fileprivate struct FrameNode<Node: ComposeNode>: ComposeNode {

    private var node: Node

    private let width: FrameSize
    private let height: FrameSize
    private let alignment: Layout.Alignment
    
    init(node: Node, width: FrameSize, height: FrameSize, alignment: Layout.Alignment) {
      self.node = node

      self.width = width
      self.height = height
      self.alignment = alignment
    }
    
    // MARK: - ComposeNode
    
    private(set) var size: CGSize = .zero
    
    mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
      let childContainerSize: CGSize
      switch (width, height) {
      case (.fixed(let width), .fixed(let height)):
        childContainerSize = CGSize(width: width, height: height)
      case (.fixed(let width), _):
        childContainerSize = CGSize(width: width, height: containerSize.height)
      case (_, .fixed(let height)):
        childContainerSize = CGSize(width: containerSize.width, height: height)
      default:
        childContainerSize = containerSize
      }
      
      let childNodeSizing = node.layout(containerSize: childContainerSize)

      let sizing: ComposeNodeSizing
      switch (width, height) {
      case (.fixed(let width), .fixed(let height)):
        size = CGSize(width: width, height: height)
        sizing = ComposeNodeSizing(width: .fixed(width), height: .fixed(height))
      case (.fixed(let width), .flexible):
        size = CGSize(width: width, height: containerSize.height)
        sizing = ComposeNodeSizing(width: .fixed(width), height: .flexible)
      case (.fixed(let width), .intrinsic):
        size = CGSize(width: width, height: node.size.height)
        sizing = ComposeNodeSizing(width: .fixed(width), height: childNodeSizing.height)
      case (.flexible, .fixed(let height)):
        size = CGSize(width: containerSize.width, height: height)
        sizing = ComposeNodeSizing(width: .flexible, height: .fixed(height))
      case (.flexible, .flexible):
        size = containerSize
        sizing = ComposeNodeSizing(width: .flexible, height: .flexible)
      case (.flexible, .intrinsic):
        size = CGSize(width: containerSize.width, height: node.size.height)
        sizing = ComposeNodeSizing(width: .flexible, height: childNodeSizing.height)
      case (.intrinsic, .fixed(let height)):
        size = CGSize(width: node.size.width, height: height)
        sizing = ComposeNodeSizing(width: childNodeSizing.width, height: .fixed(height))
      case (.intrinsic, .flexible):
        size = CGSize(width: node.size.width, height: containerSize.height)
        sizing = ComposeNodeSizing(width: childNodeSizing.width, height: .flexible)
      case (.intrinsic, .intrinsic):
        size = node.size
        sizing = childNodeSizing
      }

      return sizing
    }
    
    func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
      // the child node's frame in self's coordinates
      let childFrame = Layout.position(rect: node.size, in: size, alignment: alignment)

      // convert the bounds from self's coordinates to the child node's coordinates
      let boundsInChild = visibleBounds.translate(-childFrame.origin)

      return node.viewItems(in: boundsInChild)
        .map { item in
          item
            .id("\(ComposeNodeId.frame.rawValue)|\(item.id)")
            .frame(item.frame.translate(childFrame.origin))
        }
    }
  }
}

public extension ComposeNode {

  func frame(width: FrameSize, height: FrameSize, alignment: Layout.Alignment = .center) -> some ComposeNode {
    Compose.FrameNode(node: self, width: width, height: height, alignment: alignment)
  }

  func frame(width: CGFloat, height: FrameSize, alignment: Layout.Alignment = .center) -> some ComposeNode {
    Compose.FrameNode(node: self, width: .fixed(width), height: height, alignment: alignment)
  }

  func frame(width: FrameSize, height: CGFloat, alignment: Layout.Alignment = .center) -> some ComposeNode {
    Compose.FrameNode(node: self, width: width, height: .fixed(height), alignment: alignment)
  }

  func frame(width: CGFloat, height: CGFloat, alignment: Layout.Alignment = .center) -> some ComposeNode {
    Compose.FrameNode(node: self, width: .fixed(width), height: .fixed(height), alignment: alignment)
  }

  func frame(_ size: CGFloat, alignment: Layout.Alignment = .center) -> some ComposeNode {
    Compose.FrameNode(node: self, width: .fixed(size), height: .fixed(size), alignment: alignment)
  }

  func frame(_ size: FrameSize, alignment: Layout.Alignment = .center) -> some ComposeNode {
    Compose.FrameNode(node: self, width: size, height: size, alignment: alignment)
  }
}
