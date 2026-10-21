//
//  ComposeContentBuilder.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

import Foundation

/// A builder to compose the compose content.
///
/// A block keeps the type of each node in it until it writes its nodes into one buffer, instead of putting each node in
/// a heap box of its own.
@resultBuilder
public enum ComposeContentBuilder {

  // MARK: - Expressions

  /// For a node, which the block places as itself.
  @inlinable
  public static func buildExpression<N: ComposeNode>(_ node: consuming N) -> _Node<N> {
    _Node(node)
  }

  /// For a node in a box, which a method returning `any ComposeNode` makes.
  @_disfavoredOverload
  public static func buildExpression(_ node: any ComposeNode) -> _Content {
    // disfavored, as the one for content is, so that a node of a known type takes the generic overload and keeps its type
    _Content(node: node)
  }

  /// For content that isn't a node, which expands into its nodes.
  @_disfavoredOverload
  public static func buildExpression(_ content: any ComposeContent) -> _Content {
    // boxed instead of generic, since a boxed node opens into a generic parameter and would take a generic overload over
    // the one that keeps its box
    _Content(content)
  }

  /// For an array of content, which expands into the nodes of each.
  public static func buildExpression(_ contents: [ComposeContent]) -> _Content {
    // each element keeps its nodes as they are, so a block's nodes are copied from its buffer instead of each boxed
    _Content(contents: contents.map { _Content($0) })
  }

  /// For a void expression.
  public static func buildExpression(_ expression: Void) -> _Content {
    _Content(nodes: [])
  }

  // MARK: - Blocks

  /// For a block of one statement that's content already.
  public static func buildBlock(_ content: _Content) -> _Content {
    content
  }

  /// For a block of no statements.
  public static func buildBlock() -> _Content {
    _Content(nodes: [])
  }

  // A refresh builds every block again, so a block of up to ten statements has an overload of its own, which the
  // optimizer specializes fully and which moves each node into the buffer, where a parameter pack copies each node.
  // Each block writes its nodes when it's built, instead of keeping their types until the final result, since a loop
  // can't collect iterations whose type involves an opaque result type.

  /// For a block of one node, which writes the node into a buffer.
  @inlinable
  public static func buildBlock(_ node: consuming _Node<some ComposeNode>) -> _Content {
    let writer = _NodeWriter(capacity: 1, valuesByteCount: node.valuesByteCount)
    node.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of two statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of three statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component,
                                _ c2: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount + c2.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount + c2.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    c2.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of four statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component,
                                _ c2: consuming some _Component,
                                _ c3: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount + c2.nodeCount + c3.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount + c2.valuesByteCount + c3.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    c2.write(into: writer)
    c3.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of five statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component,
                                _ c2: consuming some _Component,
                                _ c3: consuming some _Component,
                                _ c4: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount + c2.nodeCount + c3.nodeCount + c4.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount + c2.valuesByteCount + c3.valuesByteCount + c4.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    c2.write(into: writer)
    c3.write(into: writer)
    c4.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of six statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component,
                                _ c2: consuming some _Component,
                                _ c3: consuming some _Component,
                                _ c4: consuming some _Component,
                                _ c5: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount + c2.nodeCount + c3.nodeCount + c4.nodeCount + c5.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount + c2.valuesByteCount + c3.valuesByteCount + c4.valuesByteCount + c5.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    c2.write(into: writer)
    c3.write(into: writer)
    c4.write(into: writer)
    c5.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of seven statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component,
                                _ c2: consuming some _Component,
                                _ c3: consuming some _Component,
                                _ c4: consuming some _Component,
                                _ c5: consuming some _Component,
                                _ c6: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount + c2.nodeCount + c3.nodeCount + c4.nodeCount + c5.nodeCount + c6.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount + c2.valuesByteCount + c3.valuesByteCount + c4.valuesByteCount + c5.valuesByteCount + c6.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    c2.write(into: writer)
    c3.write(into: writer)
    c4.write(into: writer)
    c5.write(into: writer)
    c6.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of eight statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component,
                                _ c2: consuming some _Component,
                                _ c3: consuming some _Component,
                                _ c4: consuming some _Component,
                                _ c5: consuming some _Component,
                                _ c6: consuming some _Component,
                                _ c7: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount + c2.nodeCount + c3.nodeCount + c4.nodeCount + c5.nodeCount + c6.nodeCount + c7.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount + c2.valuesByteCount + c3.valuesByteCount + c4.valuesByteCount + c5.valuesByteCount + c6.valuesByteCount + c7.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    c2.write(into: writer)
    c3.write(into: writer)
    c4.write(into: writer)
    c5.write(into: writer)
    c6.write(into: writer)
    c7.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of nine statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component,
                                _ c2: consuming some _Component,
                                _ c3: consuming some _Component,
                                _ c4: consuming some _Component,
                                _ c5: consuming some _Component,
                                _ c6: consuming some _Component,
                                _ c7: consuming some _Component,
                                _ c8: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount + c2.nodeCount + c3.nodeCount + c4.nodeCount + c5.nodeCount + c6.nodeCount + c7.nodeCount + c8.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount + c2.valuesByteCount + c3.valuesByteCount + c4.valuesByteCount + c5.valuesByteCount + c6.valuesByteCount + c7.valuesByteCount + c8.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    c2.write(into: writer)
    c3.write(into: writer)
    c4.write(into: writer)
    c5.write(into: writer)
    c6.write(into: writer)
    c7.write(into: writer)
    c8.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of ten statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock(_ c0: consuming some _Component,
                                _ c1: consuming some _Component,
                                _ c2: consuming some _Component,
                                _ c3: consuming some _Component,
                                _ c4: consuming some _Component,
                                _ c5: consuming some _Component,
                                _ c6: consuming some _Component,
                                _ c7: consuming some _Component,
                                _ c8: consuming some _Component,
                                _ c9: consuming some _Component) -> _Content
  {
    let nodeCount = c0.nodeCount + c1.nodeCount + c2.nodeCount + c3.nodeCount + c4.nodeCount + c5.nodeCount + c6.nodeCount + c7.nodeCount + c8.nodeCount + c9.nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: c0.valuesByteCount + c1.valuesByteCount + c2.valuesByteCount + c3.valuesByteCount + c4.valuesByteCount + c5.valuesByteCount + c6.valuesByteCount + c7.valuesByteCount + c8.valuesByteCount + c9.valuesByteCount)
    c0.write(into: writer)
    c1.write(into: writer)
    c2.write(into: writer)
    c3.write(into: writer)
    c4.write(into: writer)
    c5.write(into: writer)
    c6.write(into: writer)
    c7.write(into: writer)
    c8.write(into: writer)
    c9.write(into: writer)
    return _Content(written: writer)
  }

  /// For a block of more than ten statements, which writes its nodes into a buffer.
  @inlinable
  public static func buildBlock<each C: _Component>(_ components: repeat consuming each C) -> _Content {
    // a parameter pack, instead of a type that holds one, which needs macOS 14, iOS 17 or tvOS 17 at runtime
    var nodeCount = 0
    repeat nodeCount += (each components).nodeCount
    guard nodeCount > 0 else {
      return _Content(nodes: [])
    }
    var valuesByteCount = 0
    repeat valuesByteCount += (each components).valuesByteCount
    let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: valuesByteCount)
    repeat (each components).write(into: writer)
    return _Content(written: writer)
  }

  // MARK: - Control Flow

  /// For `if`/`else`/`switch` statements.
  public static func buildEither(first: _Content) -> _Content {
    first
  }

  /// For `if`/`else`/`switch` statements.
  public static func buildEither(second: _Content) -> _Content {
    second
  }

  /// For `if` statements without `else`.
  public static func buildOptional(_ content: _Content?) -> _Content {
    content ?? _Content(nodes: [])
  }

  /// For `for` loops.
  public static func buildArray(_ contents: [_Content]) -> _Content {
    _Content(contents: contents)
  }

  /// For `#available` statements.
  public static func buildLimitedAvailability(_ content: _Content) -> _Content {
    content
  }

  // MARK: - Final Result

  /// Returns a block's content.
  public static func buildFinalResult(_ content: _Content) -> ComposeContent {
    content.content
  }
}

// MARK: - Components

public extension ComposeContentBuilder {

  /// A statement of a block, which the block writes into its buffer. Builder plumbing.
  protocol _Component {

    /// The number of nodes.
    var nodeCount: Int { get }

    /// The number of bytes that the nodes' values take at most in a buffer.
    var valuesByteCount: Int { get }

    /// Writes the nodes, in order.
    consuming func write(into writer: _NodeWriter)
  }

  /// A node. Builder plumbing.
  @frozen
  struct _Node<N: ComposeNode>: _Component {

    @usableFromInline
    let node: N

    @inlinable
    init(_ node: consuming N) {
      self.node = node
    }

    @inlinable
    public var nodeCount: Int {
      1
    }

    @inlinable
    public var valuesByteCount: Int {
      NodeBuffer.room(for: N.self)
    }

    @inlinable
    public consuming func write(into writer: _NodeWriter) {
      writer.append(node)
    }
  }

  /// The nodes of a block, or of content that isn't a node. Builder plumbing.
  @frozen
  struct _Content: _Component {

    @usableFromInline
    enum Storage {

      /// The nodes of content that its holders can share, which a block copies.
      case shared(NodeList)

      /// The nodes that a block wrote, which only the builder holds, so the block that writes them moves them, and the
      /// content is written once.
      case written(NodeBuffer)

      /// A node in a box.
      case node(any ComposeNode)

      /// The nodes of content that isn't a node, in boxes.
      case nodes([any ComposeNode])

      /// The contents of a loop's iterations, in order, with the number of their nodes and of the bytes that the nodes'
      /// values take at most.
      case contents([_Content], nodeCount: Int, valuesByteCount: Int)
    }

    @usableFromInline
    let storage: Storage

    @usableFromInline
    init(_ content: some ComposeContent) {
      if let list = NodeList(content) {
        storage = .shared(list)
      } else {
        storage = .nodes(content._nodes())
      }
    }

    @usableFromInline
    init(node: any ComposeNode) {
      storage = .node(node)
    }

    @usableFromInline
    init(nodes: [any ComposeNode]) {
      storage = .nodes(nodes)
    }

    @inlinable
    init(written writer: _NodeWriter) {
      storage = .written(writer.buffer)
    }

    @usableFromInline
    init(contents: [_Content]) {
      // counted once here, since the enclosing block reads the counts before it writes, and so does each enclosing loop,
      // where counting each time would walk the iterations again
      var nodeCount = 0
      var valuesByteCount = 0
      for index in contents.indices {
        nodeCount += contents[index].nodeCount
        valuesByteCount += contents[index].valuesByteCount
      }
      storage = .contents(contents, nodeCount: nodeCount, valuesByteCount: valuesByteCount)
    }

    /// The nodes as content.
    @usableFromInline
    var content: ComposeContent {
      switch storage {
      case .shared(let list):
        return list
      case .written(let buffer):
        ComposeUI.assert(buffer.count > 0, "a block's content is written once, since writing it moves its nodes")
        return NodeList(buffer: buffer)
      case .node(let node):
        return [node]
      case .nodes(let nodes):
        return nodes
      case .contents(_, let nodeCount, let valuesByteCount):
        guard nodeCount > 0 else {
          return NodeList(buffer: .empty)
        }
        let writer = _NodeWriter(capacity: nodeCount, valuesByteCount: valuesByteCount)
        write(into: writer)
        return NodeList(buffer: writer.buffer)
      }
    }

    public var nodeCount: Int {
      switch storage {
      case .shared(let list):
        return list.buffer.count
      case .written(let buffer):
        return buffer.count
      case .node:
        return 1
      case .nodes(let nodes):
        return nodes.count
      case .contents(_, let nodeCount, _):
        return nodeCount
      }
    }

    public var valuesByteCount: Int {
      switch storage {
      case .shared(let list):
        return list.buffer.roomOfChildren
      case .written(let buffer):
        return buffer.roomOfChildren
      case .node(let node):
        return NodeBuffer.room(of: node)
      case .nodes(let nodes):
        return NodeBuffer.room(of: nodes)
      case .contents(_, _, let valuesByteCount):
        return valuesByteCount
      }
    }

    public func write(into writer: _NodeWriter) {
      // the content isn't taken, which would copy a loop's iteration out of its array first, and the nodes that a block
      // wrote still move, since only the builder holds them
      switch storage {
      case .shared(let list):
        writer.append(contentsOf: list.buffer)
      case .written(let buffer):
        ComposeUI.assert(buffer.count > 0, "a block's content is written once, since writing it moves its nodes")
        writer.moveChildren(of: buffer)
      case .node(let node):
        writer.append(boxed: node)
      case .nodes(let nodes):
        writer.append(contentsOf: nodes)
      case .contents(let contents, _, _):
        for index in contents.indices {
          contents[index].write(into: writer)
        }
      }
    }
  }

  /// Writes a block's nodes into a buffer. Builder plumbing.
  @frozen
  struct _NodeWriter {

    @usableFromInline
    let buffer: NodeBuffer

    @inlinable
    init(capacity: Int, valuesByteCount: Int) {
      buffer = NodeBuffer.make(capacity: capacity, valuesByteCount: valuesByteCount)
    }

    @inlinable
    func append(_ node: consuming some ComposeNode) {
      buffer.append(node)
    }

    @usableFromInline
    func append(contentsOf other: NodeBuffer) {
      buffer.append(contentsOf: other)
    }

    @usableFromInline
    func append(boxed node: any ComposeNode) {
      buffer.append(copyOf: node)
    }

    @usableFromInline
    func append(contentsOf nodes: [any ComposeNode]) {
      for node in nodes {
        buffer.append(copyOf: node)
      }
    }

    @usableFromInline
    func moveChildren(of other: NodeBuffer) {
      other.moveChildren(into: buffer)
    }
  }
}

// MARK: - NodeList

/// The content that a `@ComposeContentBuilder` block makes: its nodes, in one buffer.
@usableFromInline
struct NodeList: ComposeContent {

  @usableFromInline
  let buffer: NodeBuffer

  @usableFromInline
  init(buffer: NodeBuffer) {
    self.buffer = buffer
  }

  /// Returns content that's a block's content as it is, or nil for other content.
  ///
  /// - Parameter content: The content.
  init?<C: ComposeContent>(_ content: C) {
    // callers pass content opened from an existential, where comparing the type costs less than an `as?` cast, which
    // goes through the runtime to unwrap the existential and then to match the type
    guard C.self == NodeList.self else {
      return nil
    }
    self = unsafeBitCast(content, to: NodeList.self)
  }

  /// Returns the buffer of content's nodes: a block's buffer itself, or a buffer with copies of other content's nodes.
  ///
  /// - Parameter content: The content.
  /// - Returns: The buffer.
  static func buffer(of content: some ComposeContent) -> NodeBuffer {
    if let list = NodeList(content) {
      return list.buffer
    } else {
      return NodeBuffer.make(content.nodes)
    }
  }

  @usableFromInline
  func _nodes() -> [any ComposeNode] {
    buffer.nodes
  }
}
