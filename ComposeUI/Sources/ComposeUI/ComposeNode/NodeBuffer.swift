//
//  NodeBuffer.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/20/26.
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

/// The child nodes of a container, stored by value in one allocation, each with its type, instead of in a heap box for
/// each child and an array of the boxes.
///
/// The elements start with a table of the children's types and value offsets, followed by the children's values, each at
/// its type's alignment. A buffer is made with room for its children, which are then appended in order.
///
/// The copies of a node share its buffer, so a node makes its buffer unique with `makeUnique(_:)` before it changes a
/// child, such as when it lays its children out.
@usableFromInline
final class NodeBuffer: ManagedBuffer<NodeBuffer.Header, NodeBuffer.Chunk> {

  /// The unit of the elements, whose alignment is the largest that a child's value can have.
  @usableFromInline
  typealias Chunk = SIMD2<UInt64>

  @usableFromInline
  struct Header {

    /// The number of children appended.
    @usableFromInline
    var count: Int

    /// The number of children that the table has room for.
    @usableFromInline
    let capacity: Int

    /// The byte offset of the next child's value, from the start of the elements.
    @usableFromInline
    var nextValueOffset: Int

    /// The byte offset where the values start, from the start of the elements.
    @usableFromInline
    let valuesStart: Int

    /// The number of bytes of the elements.
    @usableFromInline
    let byteCount: Int

    @usableFromInline
    init(count: Int, capacity: Int, nextValueOffset: Int, valuesStart: Int, byteCount: Int) {
      self.count = count
      self.capacity = capacity
      self.nextValueOffset = nextValueOffset
      self.valuesStart = valuesStart
      self.byteCount = byteCount
    }
  }

  /// A child's type, and the byte offset of its value from the start of the elements.
  @usableFromInline
  struct Entry {

    @usableFromInline
    let type: any ComposeNode.Type

    @usableFromInline
    let offset: Int

    @usableFromInline
    init(type: any ComposeNode.Type, offset: Int) {
      self.type = type
      self.offset = offset
    }
  }

  // MARK: - Making

  /// Returns an empty buffer with room for a number of children whose values take at most a number of bytes.
  ///
  /// - Parameters:
  ///   - capacity: The number of children.
  ///   - valuesByteCount: The number of bytes that the children's values take at most, the sum of `room(for:)` for each
  ///     child's type.
  /// - Returns: The buffer.
  @inlinable
  static func make(capacity: Int, valuesByteCount: Int) -> NodeBuffer {
    let valuesStart = alignedOffset(capacity * MemoryLayout<Entry>.stride, alignment: MemoryLayout<Chunk>.alignment)
    let chunkCount = max((valuesStart + valuesByteCount + MemoryLayout<Chunk>.stride - 1) / MemoryLayout<Chunk>.stride, 1)
    let buffer = create(minimumCapacity: chunkCount) { _ in
      Header(
        count: 0,
        capacity: capacity,
        nextValueOffset: valuesStart,
        valuesStart: valuesStart,
        byteCount: chunkCount * MemoryLayout<Chunk>.stride
      )
    }
    return unsafeDowncast(buffer, to: NodeBuffer.self)
  }

  /// Returns a buffer with copies of the nodes, in order.
  ///
  /// - Parameter nodes: The nodes.
  /// - Returns: The buffer.
  static func make(_ nodes: [any ComposeNode]) -> NodeBuffer {
    var valuesByteCount = 0
    for node in nodes {
      valuesByteCount += room(of: node)
    }
    let buffer = make(capacity: nodes.count, valuesByteCount: valuesByteCount)
    for node in nodes {
      buffer.append(node)
    }
    return buffer
  }

  /// Returns the number of bytes that a value of a type takes at most in a buffer, with its alignment.
  ///
  /// - Parameter type: The type of the value.
  /// - Returns: The number of bytes.
  @inlinable
  static func room<N: ComposeNode>(for type: N.Type) -> Int {
    MemoryLayout<N>.size + MemoryLayout<N>.alignment - 1
  }

  /// Appends a child after the children appended before it.
  ///
  /// - Parameter node: The child, which must fit in the room that the buffer was made with.
  @inlinable
  func append<N: ComposeNode>(_ node: consuming N) {
    let pointer = withUnsafeMutablePointers { header, elements -> UnsafeMutableRawPointer in
      let alignment = MemoryLayout<N>.alignment
      precondition(alignment <= MemoryLayout<Chunk>.alignment, "a node's alignment must be at most 16 bytes")
      let offset = Self.alignedOffset(header.pointee.nextValueOffset, alignment: alignment)
      precondition(
        header.pointee.count < header.pointee.capacity && offset + MemoryLayout<N>.size <= header.pointee.byteCount,
        "a child must fit in the room that the buffer was made with"
      )
      let base = UnsafeMutableRawPointer(elements)
      (base + header.pointee.count * MemoryLayout<Entry>.stride).initializeMemory(as: Entry.self, to: Entry(type: N.self, offset: offset))
      header.pointee.count += 1
      header.pointee.nextValueOffset = offset + MemoryLayout<N>.size
      return base + offset
    }
    // the node moves in after the closure, which can't consume it
    pointer.initializeMemory(as: N.self, to: node)
  }

  /// Returns a buffer with copies of the children, in order.
  ///
  /// - Returns: The buffer.
  func copy() -> NodeBuffer {
    let header = header
    // the values take the same bytes in the copy, since they're laid out in the same order from the same alignment
    let copy = NodeBuffer.make(capacity: header.count, valuesByteCount: header.nextValueOffset - header.valuesStart)
    for index in 0 ..< header.count {
      let (type, pointer) = child(at: index)
      Self.append(type, pointer, to: copy)
    }
    return copy
  }

  /// Makes a buffer unique to its holder, replacing it with a copy when another holder shares it.
  ///
  /// - Parameter buffer: The buffer, which the holder changes a child of afterward.
  static func makeUnique(_ buffer: inout NodeBuffer) {
    if !isKnownUniquelyReferenced(&buffer) {
      buffer = buffer.copy()
    }
  }

  deinit {
    for index in 0 ..< header.count {
      let (type, pointer) = child(at: index)
      Self.deinitialize(type, pointer)
    }
  }

  // MARK: - Children

  /// The number of children.
  var count: Int {
    header.count
  }

  /// Lays out the child at an index.
  ///
  /// - Parameters:
  ///   - index: The index of the child.
  ///   - containerSize: The container size.
  ///   - context: The layout context.
  /// - Returns: The child's sizing.
  func layout(at index: Int, containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    let (type, pointer) = child(at: index)
    return Self.layout(type, pointer, containerSize, context)
  }

  /// Returns the size of the child at an index.
  ///
  /// - Parameter index: The index of the child.
  /// - Returns: The size.
  func size(at index: Int) -> CGSize {
    let (type, pointer) = child(at: index)
    return Self.size(type, pointer)
  }

  /// Returns the bounding rect of the renderable items of the child at an index.
  ///
  /// - Parameter index: The index of the child.
  /// - Returns: The bounding rect.
  func renderableItemsBoundingRect(at index: Int) -> CGRect {
    let (type, pointer) = child(at: index)
    return Self.renderableItemsBoundingRect(type, pointer)
  }

  /// Appends the renderable items of the child at an index in its visible bounds.
  ///
  /// - Parameters:
  ///   - index: The index of the child.
  ///   - visibleBounds: The child's visible bounds.
  ///   - items: The items to append to.
  func render(at index: Int, visibleBounds: CGRect, into items: inout [RenderableItem]) {
    let (type, pointer) = child(at: index)
    Self.render(type, pointer, visibleBounds, &items)
  }

  /// Calls a block with the child at an index in place, if the child is of a type.
  ///
  /// - Parameters:
  ///   - index: The index of the child.
  ///   - type: The type.
  ///   - body: The block, which can change the child.
  /// - Returns: The block's result, or `nil` if the child is of another type.
  func withNode<N: ComposeNode, R>(at index: Int, as type: N.Type, _ body: (inout N) -> R) -> R? {
    let (childType, pointer) = child(at: index)
    guard childType == N.self else {
      return nil
    }
    return body(&pointer.assumingMemoryBound(to: N.self).pointee)
  }

  /// Returns a copy of the child at an index, in a box of its own.
  ///
  /// - Parameter index: The index of the child.
  /// - Returns: The copy.
  func node(at index: Int) -> any ComposeNode {
    let (type, pointer) = child(at: index)
    return Self.node(type, pointer)
  }

  /// Returns the type of the child at an index and the address of its value, which stays valid while the buffer lives.
  private func child(at index: Int) -> (type: any ComposeNode.Type, pointer: UnsafeMutableRawPointer) {
    precondition(index >= 0 && index < header.count, "index out of range")
    return withUnsafeMutablePointerToElements { elements in
      let base = UnsafeMutableRawPointer(elements)
      let entry = base.assumingMemoryBound(to: Entry.self)[index]
      return (entry.type, base + entry.offset)
    }
  }

  // MARK: - Helpers

  /// Returns an offset rounded up to an alignment, which is a power of two.
  @inlinable
  static func alignedOffset(_ offset: Int, alignment: Int) -> Int {
    (offset + alignment - 1) & ~(alignment - 1)
  }

  private static func deinitialize<N: ComposeNode>(_: N.Type, _ pointer: UnsafeMutableRawPointer) {
    pointer.assumingMemoryBound(to: N.self).deinitialize(count: 1)
  }

  private static func room<N: ComposeNode>(of _: N) -> Int {
    room(for: N.self)
  }

  private static func append<N: ComposeNode>(_: N.Type, _ pointer: UnsafeMutableRawPointer, to buffer: NodeBuffer) {
    buffer.append(pointer.assumingMemoryBound(to: N.self).pointee)
  }

  private static func layout<N: ComposeNode>(_: N.Type,
                                             _ pointer: UnsafeMutableRawPointer,
                                             _ containerSize: CGSize,
                                             _ context: ComposeNodeLayoutContext) -> ComposeNodeSizing
  {
    pointer.assumingMemoryBound(to: N.self).pointee.layout(containerSize: containerSize, context: context)
  }

  private static func size<N: ComposeNode>(_: N.Type, _ pointer: UnsafeMutableRawPointer) -> CGSize {
    // the child is passed in place, as it is for its bounding rect and its render, since reading it through `pointee`
    // in unspecialized code copies the whole child first
    size(of: &pointer.assumingMemoryBound(to: N.self).pointee)
  }

  private static func size(of node: inout some ComposeNode) -> CGSize {
    node.size
  }

  private static func renderableItemsBoundingRect<N: ComposeNode>(_: N.Type, _ pointer: UnsafeMutableRawPointer) -> CGRect {
    renderableItemsBoundingRect(of: &pointer.assumingMemoryBound(to: N.self).pointee)
  }

  private static func renderableItemsBoundingRect(of node: inout some ComposeNode) -> CGRect {
    node.renderableItemsBoundingRect
  }

  private static func render<N: ComposeNode>(_: N.Type,
                                             _ pointer: UnsafeMutableRawPointer,
                                             _ visibleBounds: CGRect,
                                             _ items: inout [RenderableItem])
  {
    render(&pointer.assumingMemoryBound(to: N.self).pointee, visibleBounds, &items)
  }

  private static func render(_ node: inout some ComposeNode, _ visibleBounds: CGRect, _ items: inout [RenderableItem]) {
    node.render(visibleBounds: visibleBounds, into: &items)
  }

  private static func node<N: ComposeNode>(_: N.Type, _ pointer: UnsafeMutableRawPointer) -> any ComposeNode {
    pointer.assumingMemoryBound(to: N.self).pointee
  }
}
