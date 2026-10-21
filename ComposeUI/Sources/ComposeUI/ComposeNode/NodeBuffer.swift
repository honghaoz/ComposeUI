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
    let childCapacity: Int

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
    init(count: Int, childCapacity: Int, nextValueOffset: Int, valuesStart: Int, byteCount: Int) {
      self.count = count
      self.childCapacity = childCapacity
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
        childCapacity: capacity,
        nextValueOffset: valuesStart,
        valuesStart: valuesStart,
        byteCount: chunkCount * MemoryLayout<Chunk>.stride
      )
    }
    return unsafeDowncast(buffer, to: NodeBuffer.self)
  }

  /// The buffer that empty content shares, since it has no child to change.
  static let empty = make(capacity: 0, valuesByteCount: 0)

  /// Returns a buffer with copies of the nodes, in order, or the shared empty buffer for no nodes.
  ///
  /// - Parameter nodes: The nodes.
  /// - Returns: The buffer.
  static func make(_ nodes: [any ComposeNode]) -> NodeBuffer {
    guard !nodes.isEmpty else {
      return empty
    }
    let buffer = make(capacity: nodes.count, valuesByteCount: room(of: nodes))
    for node in nodes {
      buffer.append(copyOf: node)
    }
    return buffer
  }

  /// Returns the number of bytes that a value of a type takes at most in a buffer: its stride and the padding to its
  /// alignment.
  ///
  /// - Parameter type: The type of the value.
  /// - Returns: The number of bytes.
  @inlinable
  static func room<N: ComposeNode>(for type: N.Type) -> Int {
    MemoryLayout<N>.stride + MemoryLayout<N>.alignment - 1
  }

  /// Returns the number of bytes that a node's value takes at most in a buffer, with its alignment.
  ///
  /// - Parameter node: The node.
  /// - Returns: The number of bytes.
  static func room<N: ComposeNode>(of node: N) -> Int {
    room(for: N.self)
  }

  /// Returns the number of bytes that the nodes' values take at most in a buffer, with their alignment.
  ///
  /// - Parameter nodes: The nodes.
  /// - Returns: The number of bytes.
  static func room(of nodes: [any ComposeNode]) -> Int {
    var room = 0
    for node in nodes {
      room += self.room(of: node)
    }
    return room
  }

  /// Appends a child after the children appended before it.
  ///
  /// - Parameter node: The child, which must fit in the room that the buffer was made with.
  @inlinable
  func append<N: ComposeNode>(_ node: consuming N) {
    // the node moves in after the closure that adds its entry, which can't consume it, at an address that stays valid after
    // the closure, since a managed buffer's elements never move while the buffer lives
    appendEntry(for: N.self).initializeMemory(as: N.self, to: node)
  }

  /// Appends a copy of a node in a box after the children appended before it.
  ///
  /// - Parameter node: The node, which must fit in the room that the buffer was made with.
  func append(copyOf node: any ComposeNode) {
    Self.appendCopy(of: node, to: self)
  }

  /// Adds the entry of a child of a type after the children appended before it, and returns the address of the child's
  /// value, which the caller initializes.
  ///
  /// - Parameter type: The type of the child, which must fit in the room that the buffer was made with.
  /// - Returns: The address of the child's value.
  @inlinable
  func appendEntry<N: ComposeNode>(for type: N.Type) -> UnsafeMutableRawPointer {
    withUnsafeMutablePointers { header, elements in
      let alignment = MemoryLayout<N>.alignment
      // Swift caps a type's alignment at 16 bytes, the chunks' alignment, so this holds for every node
      precondition(alignment <= MemoryLayout<Chunk>.alignment, "a node's alignment must be at most 16 bytes")
      let offset = Self.alignedOffset(header.pointee.nextValueOffset, alignment: alignment)
      precondition(
        header.pointee.count < header.pointee.childCapacity && offset + MemoryLayout<N>.stride <= header.pointee.byteCount,
        "a child must fit in the room that the buffer was made with"
      )
      let base = UnsafeMutableRawPointer(elements)
      (base + header.pointee.count * MemoryLayout<Entry>.stride).initializeMemory(as: Entry.self, to: Entry(type: N.self, offset: offset))
      header.pointee.count += 1
      // the value takes its stride, since initializing it binds the stride's bytes to its type, so the next value starts
      // after its tail padding
      header.pointee.nextValueOffset = offset + MemoryLayout<N>.stride
      return base + offset
    }
  }

  /// Appends copies of another buffer's children, in order.
  ///
  /// - Parameter other: The other buffer, whose children must fit in the room that this buffer was made with.
  func append(contentsOf other: NodeBuffer) {
    for index in 0 ..< other.count {
      let (type, pointer) = other.child(at: index)
      Self.appendCopy(type, pointer, to: self)
    }
  }

  /// Moves the children into another buffer, in order, which leaves this buffer empty.
  ///
  /// - Parameter other: The other buffer, whose room the children must fit in.
  func moveChildren(into other: NodeBuffer) {
    for index in 0 ..< count {
      let (type, pointer) = child(at: index)
      Self.move(type, pointer, to: other)
    }
    withUnsafeMutablePointerToHeader { header in
      header.pointee.count = 0
      header.pointee.nextValueOffset = header.pointee.valuesStart
    }
  }

  /// Returns a buffer with copies of the children, in order, with room for only those children.
  ///
  /// - Returns: The buffer.
  func copy() -> NodeBuffer {
    let header = headerValue
    // the values take the same bytes in the copy, since they're laid out in the same order from the same alignment
    let copy = NodeBuffer.make(capacity: header.count, valuesByteCount: header.nextValueOffset - header.valuesStart)
    copy.append(contentsOf: self)
    return copy
  }

  /// Makes a buffer unique to its holder, replacing it with a copy when another holder shares it and it has children.
  ///
  /// - Parameter buffer: The buffer, which the holder changes a child of afterward.
  static func makeUnique(_ buffer: inout NodeBuffer) {
    // an empty buffer stays shared, since it has no child to change, which keeps empty content from allocating
    if !isKnownUniquelyReferenced(&buffer), buffer.count > 0 {
      buffer = buffer.copy()
    }
  }

  deinit {
    for index in 0 ..< headerValue.count {
      let (type, pointer) = child(at: index)
      Self.deinitialize(type, pointer)
    }
  }

  // MARK: - Children

  /// The number of children.
  var count: Int {
    headerValue.count
  }

  /// The children, each in a box of its own.
  var nodes: [any ComposeNode] {
    (0 ..< count).map { node(at: $0) }
  }

  /// The number of bytes that the children's values take at most in another buffer.
  var roomOfChildren: Int {
    let header = headerValue
    guard header.count > 0 else {
      // without values there's nothing to pad to a 16-byte boundary, so empty content adds no bytes to the buffer of a
      // block that holds it
      return 0
    }
    // from an offset of any alignment, the values take at most the bytes up to the next 16-byte boundary more than they
    // take from one, since rounding each offset up never moves a later value past where it starts from the boundary
    return header.nextValueOffset - header.valuesStart + MemoryLayout<Chunk>.alignment - 1
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

  /// Returns the type of the child at an index and the address of its value, which stays valid after the closure that
  /// reads it while the buffer lives, since a managed buffer's elements never move.
  private func child(at index: Int) -> (type: any ComposeNode.Type, pointer: UnsafeMutableRawPointer) {
    withUnsafeMutablePointers { header, elements in
      precondition(index >= 0 && index < header.pointee.count, "index out of range")
      let base = UnsafeMutableRawPointer(elements)
      let entry = base.assumingMemoryBound(to: Entry.self)[index]
      return (entry.type, base + entry.offset)
    }
  }

  // MARK: - Helpers

  /// The header, read through its address, since reading the `header` property checks exclusive access at run time.
  private var headerValue: Header {
    withUnsafeMutablePointerToHeader { $0.pointee }
  }

  /// Returns an offset rounded up to an alignment, which is a power of two.
  @inlinable
  static func alignedOffset(_ offset: Int, alignment: Int) -> Int {
    (offset + alignment - 1) & ~(alignment - 1)
  }

  private static func deinitialize<N: ComposeNode>(_: N.Type, _ pointer: UnsafeMutableRawPointer) {
    pointer.assumingMemoryBound(to: N.self).deinitialize(count: 1)
  }

  private static func appendCopy<N: ComposeNode>(of node: N, to buffer: NodeBuffer) {
    // in unspecialized code, initializing from a value costs less than initializing from an address, which calls the
    // runtime's copy of an array, while moving from an address costs less than moving the value out first
    buffer.appendEntry(for: N.self).initializeMemory(as: N.self, to: node)
  }

  private static func appendCopy<N: ComposeNode>(_: N.Type, _ pointer: UnsafeMutableRawPointer, to buffer: NodeBuffer) {
    buffer.appendEntry(for: N.self).initializeMemory(as: N.self, to: pointer.assumingMemoryBound(to: N.self).pointee)
  }

  private static func move<N: ComposeNode>(_: N.Type, _ pointer: UnsafeMutableRawPointer, to buffer: NodeBuffer) {
    _ = buffer.appendEntry(for: N.self).moveInitializeMemory(as: N.self, from: pointer.assumingMemoryBound(to: N.self), count: 1)
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
