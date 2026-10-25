//
//  AxisStack.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/24/26.
//  Copyright © 2024 Honghao Zhang.
//
//  MIT License
//
//  Copyright (c) 2024 Honghao Zhang (github.com/honghaoz)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import CoreGraphics

/// The axis that a stack lays out its children along.
///
/// A stack reads its axis from its type instead of a stored value, so that its layout and render, which the optimizer
/// specializes for each axis, check no axis at run time.
protocol StackAxis {

  /// The alignment of the children across the axis.
  associatedtype CrossAlignment

  /// The axis.
  static var mainAxis: StackLayoutCache.MainAxis { get }

  /// Returns the position of a child across the axis.
  ///
  /// - Parameters:
  ///   - childLength: The child's length across the axis.
  ///   - length: The stack's length across the axis.
  ///   - alignment: The alignment of the children across the axis.
  /// - Returns: The child's position across the axis.
  static func crossPosition(of childLength: CGFloat, in length: CGFloat, alignment: CrossAlignment) -> CGFloat
}

extension StackAxis {

  /// Returns a size's length along the axis.
  static func main(of size: CGSize) -> CGFloat {
    switch mainAxis {
    case .horizontal:
      return size.width
    case .vertical:
      return size.height
    }
  }

  /// Returns a size's length across the axis.
  static func cross(of size: CGSize) -> CGFloat {
    switch mainAxis {
    case .horizontal:
      return size.height
    case .vertical:
      return size.width
    }
  }

  /// Returns the size of the lengths along and across the axis.
  static func size(main: CGFloat, cross: CGFloat) -> CGSize {
    switch mainAxis {
    case .horizontal:
      return CGSize(width: main, height: cross)
    case .vertical:
      return CGSize(width: cross, height: main)
    }
  }

  /// Returns the point at the positions along and across the axis.
  static func point(main: CGFloat, cross: CGFloat) -> CGPoint {
    switch mainAxis {
    case .horizontal:
      return CGPoint(x: main, y: cross)
    case .vertical:
      return CGPoint(x: cross, y: main)
    }
  }

  /// Returns a rect's minimum position along the axis.
  ///
  /// - Parameter edges: The rect's edges, as `CGRect.edgesInline` gives them.
  /// - Returns: The rect's minimum position along the axis.
  static func minMain(of edges: (minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat)) -> CGFloat {
    switch mainAxis {
    case .horizontal:
      return edges.minX
    case .vertical:
      return edges.minY
    }
  }

  /// Returns a rect's maximum position along the axis.
  ///
  /// - Parameter edges: The rect's edges, as `CGRect.edgesInline` gives them.
  /// - Returns: The rect's maximum position along the axis.
  static func maxMain(of edges: (minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat)) -> CGFloat {
    switch mainAxis {
    case .horizontal:
      return edges.maxX
    case .vertical:
      return edges.maxY
    }
  }

  /// Returns a sizing's sizing along the axis.
  static func main(of sizing: ComposeNodeSizing) -> ComposeNodeSizing.Sizing {
    switch mainAxis {
    case .horizontal:
      return sizing.width
    case .vertical:
      return sizing.height
    }
  }

  /// Returns a sizing's sizing across the axis.
  static func cross(of sizing: ComposeNodeSizing) -> ComposeNodeSizing.Sizing {
    switch mainAxis {
    case .horizontal:
      return sizing.height
    case .vertical:
      return sizing.width
    }
  }

  /// Returns the sizing of the sizings along and across the axis, made by a layout that depended on the given lengths.
  static func sizing(main: ComposeNodeSizing.Sizing, cross: ComposeNodeSizing.Sizing, dependence: ComposeNodeSizing.Dependence) -> ComposeNodeSizing {
    switch mainAxis {
    case .horizontal:
      return ComposeNodeSizing(width: main, height: cross, dependence: dependence)
    case .vertical:
      return ComposeNodeSizing(width: cross, height: main, dependence: dependence)
    }
  }

  /// The container length along the axis, as a dependence.
  static var mainDependence: ComposeNodeSizing.Dependence {
    switch mainAxis {
    case .horizontal:
      return .width
    case .vertical:
      return .height
    }
  }
}

/// The children of a vertical or horizontal stack, and their layout along the stack's axis.
///
/// The stack's length along the axis is the sum of its children's lengths plus the spacing between them, and its length
/// across the axis is the maximum length of its children.
struct AxisStack<Axis: StackAxis> {

  /// The latest layout's pass, container size and sizing, which a layout in the same pass at a container size that
  /// differs only in lengths that the layout didn't read returns instead of laying out the children again.
  ///
  /// Declared first, so that the one-byte `alignment` declared after it goes into the padding after its sizing instead
  /// of taking an 8-byte slot of its own, which keeps the stack, and each node or buffer that stores one, 8 bytes smaller.
  private var lastLayout: (passId: UInt64, containerSize: CGSize, sizing: ComposeNodeSizing)?

  private let alignment: Axis.CrossAlignment
  private let spacing: CGFloat

  /// The children, by value in one buffer.
  private var children: NodeBuffer

  /// The stack's size, from its latest layout.
  private(set) var size: CGSize = .zero

  /// The cached children layout information, used to cull invisible children in `render(visibleBounds:into:id:)`.
  private var layoutCache = StackLayoutCache()

  /// Creates a stack of the children in a buffer.
  ///
  /// - Parameters:
  ///   - alignment: The alignment of the children across the axis.
  ///   - spacing: The spacing between the children.
  ///   - children: The children.
  init(alignment: Axis.CrossAlignment, spacing: CGFloat, children: NodeBuffer) {
    self.alignment = alignment
    self.spacing = spacing
    self.children = children
  }

  /// The children, each in a box of its own.
  var childNodes: [any ComposeNode] {
    get {
      children.nodes
    }
    set {
      children = NodeBuffer.make(newValue)
      lastLayout = nil
    }
  }

  /// The bounding rect of the children's renderable items, from the latest layout.
  var renderableItemsBoundingRect: CGRect {
    layoutCache.itemsBoundingRect
  }

  /// Lays out the children along the axis in the container size.
  ///
  /// - Parameters:
  ///   - containerSize: The proposed container size.
  ///   - context: The layout context.
  /// - Returns: The stack's sizing.
  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    // a stack lays out each flexible child twice, for its sizing and at its proposed size, so without returning a
    // layout made earlier in the pass at a container size with the same lengths that the layout depended on, each
    // enclosing stack with a flexible child would double the layouts of the nodes in it, and a stack of fixed rows that
    // a flexible stack holds would lay out its rows again for each length that the flexible stack is given
    if let lastLayout, lastLayout.passId == context.passId, lastLayout.sizing.dependence.isSame(lastLayout.containerSize, as: containerSize) {
      #if COMPOSEUI_SANITY_CHECKS
      if lastLayout.containerSize != containerSize, ComposeNodeSizing.Dependence.checksKeptLayouts {
        return layoutCheckingKeptLayout(lastLayout, containerSize: containerSize, context: context)
      }
      #endif
      return lastLayout.sizing
    }

    // the children change in place as they lay out, so a copy of the stack that shares them gets its own
    NodeBuffer.makeUnique(&children)

    guard children.count > 0 else {
      size = .zero
      layoutCache = StackLayoutCache()
      return ComposeNodeSizing(width: .fixed(0), height: .fixed(0), dependence: [])
    }

    let childCount = children.count

    let totalSpacing = spacing * CGFloat(childCount - 1)

    var mainSizing: ComposeNodeSizing.Sizing = .fixed(totalSpacing)
    var crossSizing: ComposeNodeSizing.Sizing = .fixed(0)

    // the space along the axis is distributed only when a flexible or range child can take part of it, since the
    // distribution's proposals for fixed children go unused
    var hasExpandableChild = false
    var hasInvalidFixedLength = false

    // the stack's layout depends on the container lengths that its children's layouts depend on, since it passes them
    // on, and on its length along the axis when it distributes it
    var dependence: ComposeNodeSizing.Dependence = []

    // the children's sizings and proposed lengths along the axis are needed only during this layout, so they're in
    // temporary memory
    withUnsafeTemporaryAllocation(of: ComposeNodeSizing.Sizing.self, capacity: childCount) { childMainSizings in
      // first pass: collect children's sizings
      for nodeIndex in 0 ..< childCount {

        // a spacer without a length across the axis gets a length of 0, so that spacers don't make the stack longer
        // across its axis
        children.withNode(at: nodeIndex, as: SpacerNode.self) { spacer in
          switch Axis.mainAxis {
          case .horizontal:
            spacer.zeroHeightIfSpacerWithoutHeight()
          case .vertical:
            spacer.zeroWidthIfSpacerWithoutWidth()
          }
        }

        let childSizing = children.layout(at: nodeIndex, containerSize: containerSize, context: context)
        dependence.formUnion(childSizing.dependence)

        let childMainSizing = Axis.main(of: childSizing)
        mainSizing = mainSizing.combine(with: childMainSizing, axis: .main)
        childMainSizings.initializeElement(at: nodeIndex, to: childMainSizing)
        switch childMainSizing {
        case .fixed(let length):
          hasInvalidFixedLength = hasInvalidFixedLength || length < 0 || length == .infinity
        case .flexible,
             .range:
          hasExpandableChild = true
        }

        crossSizing = crossSizing.combine(with: Axis.cross(of: childSizing), axis: .cross)
      }

      if hasExpandableChild {
        dependence.formUnion(Axis.mainDependence)
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: childCount) { proposedMainLengths in
          let remainingMainLength = Axis.main(of: containerSize) - totalSpacing
          Layout.stackLayout(space: remainingMainLength, items: UnsafeBufferPointer(childMainSizings), into: proposedMainLengths)
          proposedMainLengths.round(scaleFactor: context.scaleFactor)

          // second pass: layout children with proposed lengths along the axis
          for nodeIndex in 0 ..< childCount {
            switch childMainSizings[nodeIndex] {
            case .flexible,
                 .range:
              let childSizing = children.layout(
                at: nodeIndex,
                containerSize: Axis.size(main: proposedMainLengths[nodeIndex], cross: Axis.cross(of: containerSize)),
                context: context
              )
              dependence.formUnion(childSizing.dependence)
            case .fixed:
              // skips the nodes of a fixed length along the axis as they don't need to be laid out again
              continue
            }
          }
        }
      } else if hasInvalidFixedLength {
        // the distribution normalizes each sizing, which reports an invalid length, so a stack of fixed children reports
        // them here instead
        for nodeIndex in 0 ..< childCount {
          _ = childMainSizings[nodeIndex].normalized()
        }
      }

      childMainSizings.deinitialize()
    }

    var maxChildCrossLength: CGFloat = 0
    var totalChildMainLength: CGFloat = 0
    for index in 0 ..< childCount {
      let childSize = children.size(at: index)
      maxChildCrossLength = max(maxChildCrossLength, Axis.cross(of: childSize))
      totalChildMainLength += Axis.main(of: childSize)
    }

    size = Axis.size(main: totalChildMainLength + totalSpacing, cross: maxChildCrossLength)

    // cache the children layout information for render(visibleBounds:into:id:)
    layoutCache.reset(reservingCapacity: childCount)

    var mainPosition: CGFloat = 0
    for index in 0 ..< childCount {
      let childSize = children.size(at: index)

      let crossPosition = Axis.crossPosition(of: Axis.cross(of: childSize), in: maxChildCrossLength, alignment: alignment)
      let childOrigin = Axis.point(main: mainPosition, cross: crossPosition)
      let itemsBoundingRect = children.renderableItemsBoundingRect(at: index)
      layoutCache.appendChild(
        origin: childOrigin,
        itemsBoundingRect: itemsBoundingRect.isNullInline ? itemsBoundingRect : itemsBoundingRect.translate(childOrigin)
      )

      mainPosition += Axis.main(of: childSize) + spacing
    }

    layoutCache.finish(mainAxis: Axis.mainAxis)

    let sizing = Axis.sizing(main: mainSizing, cross: crossSizing, dependence: dependence)
    lastLayout = (context.passId, containerSize, sizing)
    return sizing
  }

  #if COMPOSEUI_SANITY_CHECKS
  /// Lays out the children again at a container size that differs from the kept layout's only in lengths that the kept
  /// layout didn't read, and asserts that the new layout has the same sizing, size, and children's positions and items
  /// bounding rects, which a child's wrong dependence that changes any of them breaks.
  ///
  /// - Parameters:
  ///   - keptLayout: The latest layout in the pass, which the stack would keep.
  ///   - containerSize: The container size to lay out the children in.
  ///   - context: The layout context.
  /// - Returns: The new layout's sizing.
  @inline(never)
  private mutating func layoutCheckingKeptLayout(_ keptLayout: (passId: UInt64, containerSize: CGSize, sizing: ComposeNodeSizing),
                                                 containerSize: CGSize,
                                                 context: ComposeNodeLayoutContext) -> ComposeNodeSizing
  {
    let keptSize = size
    let keptLayoutCache = layoutCache

    // without a latest layout, the stack lays out its children instead of returning the kept layout
    lastLayout = nil
    let sizing = layout(containerSize: containerSize, context: context)

    ComposeUI.assert(
      sizing == keptLayout.sizing && size == keptSize && layoutCache.hasSameChildren(as: keptLayoutCache),
      ComposeNodeSizing.Dependence.keptLayoutMismatchMessage(
        keptContainerSize: keptLayout.containerSize,
        keptSize: keptSize,
        containerSize: containerSize,
        size: size
      )
    )
    return sizing
  }
  #endif

  /// Renders the children that are visible in the given bounds, by appending their renderable items to an array.
  ///
  /// It's always inlined, since its specialization for an axis takes the stack by value, which is too big for registers,
  /// so a call would copy the whole stack to pass it.
  ///
  /// - Parameters:
  ///   - visibleBounds: The visible bounds, in the stack's coordinate space.
  ///   - items: The array to append the items to.
  ///   - id: The stack node's id, which the children's item ids join.
  @inline(__always)
  func render(visibleBounds: CGRect, into items: inout [RenderableItem], id: ComposeNodeId) {
    guard layoutCache.childCount == children.count else {
      ComposeUI.assertFailure("render(visibleBounds:into:) requires layout(containerSize:context:) to be called first")
      return
    }

    // null bounds show nothing, and the edges of other bounds are computed inline, instead of with two calls into
    // CoreGraphics in each render
    guard !visibleBounds.isNullInline else {
      return
    }
    let visibleEdges = visibleBounds.edgesInline
    let visibleChildRange = layoutCache.visibleChildRange(
      minPosition: Axis.minMain(of: visibleEdges),
      maxPosition: Axis.maxMain(of: visibleEdges)
    )

    // each visible child appends its items to the pass's array, where they're changed in place
    for i in visibleChildRange {
      let childOrigin = layoutCache.child(at: i).origin
      let boundsInChild = visibleBounds.translate(-childOrigin)
      let start = items.count
      children.render(at: i, visibleBounds: boundsInChild, into: &items)
      guard items.count > start else {
        continue
      }

      // the child's items share one suffix, which is made once for the child instead of once for each item
      let suffix = "\(i)"
      for index in start ..< items.count {
        items[index].id = id.join(with: items[index].id, suffix: suffix)
        items[index].frame = items[index].frame.translate(childOrigin)
      }
    }
  }
}
