//
//  ComposeNodeIdTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/5/24.
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

import ChouTiTest

@testable import ComposeUI

class ComposeNodeIdTests: XCTestCase {

  func test_standard() {
    let id = ComposeNodeId.standard(.color)
    expect(id.id) == "C"
  }

  func test_custom() {
    let id = ComposeNodeId.custom("test")
    expect(id.id) == "test"

    let parentId = ComposeNodeId.custom("parent")
    do {
      let childId = parentId.join(with: id)
      expect(childId.id) == "parent|test"
    }
    do {
      let childId = parentId.join(with: id, suffix: "suffix")
      expect(childId.id) == "parent|suffix|test"
    }
  }

  func test_custom_fixed() {
    let id = ComposeNodeId.custom("test", isFixed: true)
    expect(id.id) == "test"

    let parentId = ComposeNodeId.custom("parent", isFixed: false)
    do {
      let childId = parentId.join(with: id)
      expect(childId.id) == "test"
    }
    do {
      let childId = parentId.join(with: id, suffix: "suffix")
      expect(childId.id) == "test"
    }
  }
}

// MARK: - Performance Tests

/// Performance tests for the different `ComposeNodeId` implementations.
class ComposeNodeIdPerformanceTests: XCTestCase {

  struct StringBasedNodeId {

    let id: String
    let isFixed: Bool

    func join(with child: StringBasedNodeId, suffix: String) -> StringBasedNodeId {
      if child.isFixed {
        return child
      } else {
        return StringBasedNodeId(id: "\(id)|\(suffix)|\(child.id)", isFixed: isFixed)
      }
    }
  }

  struct NestedEnumBasedNodeId {

    indirect enum Id: Hashable {

      case standard(StandardComposeNodeId)
      case custom(String)
      case nested(parent: Id, suffix: String?, child: Id)
    }

    let id: Id
    let isFixed: Bool

    func join(with child: NestedEnumBasedNodeId, suffix: String) -> NestedEnumBasedNodeId {
      if child.isFixed {
        return child
      } else {
        return NestedEnumBasedNodeId(id: .nested(parent: id, suffix: suffix, child: child.id), isFixed: isFixed)
      }
    }
  }

  class NestedEnumBasedNodeId2: Hashable {

    indirect enum Id: Hashable {

      case standard(StandardComposeNodeId)
      case custom(String)
      case nested(parent: Id, suffix: String?, child: Id)
    }

    let id: Id
    let isFixed: Bool

    private var _cachedHash: Int?

    init(id: Id, isFixed: Bool) {
      self.id = id
      self.isFixed = isFixed
    }

    func join(with child: NestedEnumBasedNodeId2, suffix: String) -> NestedEnumBasedNodeId2 {
      if child.isFixed {
        return child
      } else {
        return NestedEnumBasedNodeId2(id: .nested(parent: id, suffix: suffix, child: child.id), isFixed: isFixed)
      }
    }

    func hash(into hasher: inout Hasher) {
      if let cachedHash = _cachedHash {
        hasher.combine(cachedHash)
      } else {
        hasher.combine(id)
        _cachedHash = hasher.finalize()
      }
    }

    static func == (lhs: NestedEnumBasedNodeId2, rhs: NestedEnumBasedNodeId2) -> Bool {
      lhs.hashValue == rhs.hashValue
    }
  }

  final class LinkedListNode<T> {

    /// The value of the node.
    var value: T

    /// The next node.
    var next: LinkedListNode<T>?

    init(value: T) {
      self.value = value
    }
  }

  class LinkedListBasedNodeId: Hashable {

    struct Value {
      let id: String
      var tag: String?
      let isFixed: Bool
    }

    let node: LinkedListNode<Value>

    init(id: String, isFixed: Bool) {
      self.node = LinkedListNode(value: Value(id: id, isFixed: isFixed))
    }

    func add(to parent: LinkedListBasedNodeId, tag: String) {
      guard !node.value.isFixed else {
        return
      }

      self.node.value.tag = tag
      self.node.next = parent.node
    }

    func join(with child: LinkedListBasedNodeId, suffix: String) -> LinkedListBasedNodeId {
      child.add(to: self, tag: suffix)
      return child
    }

    private(set) lazy var idString: String = {
      var components: [String] = [node.value.id]
      if let tag = node.value.tag {
        components.append(tag)
      }

      var current = node.next
      while let unwrapped = current {
        components.append(unwrapped.value.id)
        if let tag = unwrapped.value.tag {
          components.append(tag)
        }
        current = unwrapped.next
      }
      return components.reversed().joined(separator: "|")
    }()

    static func == (lhs: LinkedListBasedNodeId, rhs: LinkedListBasedNodeId) -> Bool {
      lhs.idString == rhs.idString
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(idString)
    }
  }

  // MARK: - Performance Tests

  func test_creationPerformance() {
    // test creating deep hierarchies
    let hierarchyDepth = 10
    let iterations = 10000

    let stringIdTime = ChouTiTest.measure(repeat: iterations) {
      var id = StringBasedNodeId(id: "AA", isFixed: false)
      for i in 1 ... hierarchyDepth {
        let child = StringBasedNodeId(id: "B\(i)", isFixed: false)
        id = id.join(with: child, suffix: "1")
      }
    }

    let nestedEnumIdTime = ChouTiTest.measure(repeat: iterations) {
      var id = NestedEnumBasedNodeId(id: .custom("AA"), isFixed: false)
      for i in 1 ... hierarchyDepth {
        let child = NestedEnumBasedNodeId(id: .custom("B\(i)"), isFixed: false)
        id = id.join(with: child, suffix: "1")
      }
    }

    let nestedEnumId2Time = ChouTiTest.measure(repeat: iterations) {
      var id = NestedEnumBasedNodeId2(id: .custom("AA"), isFixed: false)
      for i in 1 ... hierarchyDepth {
        let child = NestedEnumBasedNodeId2(id: .custom("B\(i)"), isFixed: false)
        id = id.join(with: child, suffix: "1")
      }
    }

    let linkedListIdTime = ChouTiTest.measure(repeat: iterations) {
      var id = LinkedListBasedNodeId(id: "AA", isFixed: false)
      for i in 1 ... hierarchyDepth {
        let child = LinkedListBasedNodeId(id: "B\(i)", isFixed: false)
        id = id.join(with: child, suffix: "1")
      }
    }

    let stringMs = stringIdTime * 1000
    let nestedEnumMs = nestedEnumIdTime * 1000
    let nestedEnumId2Ms = nestedEnumId2Time * 1000
    let linkedListMs = linkedListIdTime * 1000

    print("""
    ComposeNodeId Creation Performance Comparison:
    • String-based:     \(String(format: "%.2f", stringMs)) ms
    • NestedEnum-based: \(String(format: "%.2f", nestedEnumMs)) ms
    • NestedEnum2-based: \(String(format: "%.2f", nestedEnumId2Ms)) ms
    • LinkedList-based: \(String(format: "%.2f", linkedListMs)) ms
    """)
  }

  func test_hashPerformance() {
    // test hashing deep hierarchies
    let hierarchyDepth = 10
    let iterations = 10000

    var stringBasedIds = [String: Int]()
    var stringBasedId = StringBasedNodeId(id: "AA", isFixed: false)
    for i in 1 ... hierarchyDepth {
      let child = StringBasedNodeId(id: "B\(i)", isFixed: false)
      stringBasedId = stringBasedId.join(with: child, suffix: "1")
    }
    let stringIdTime = ChouTiTest.measure(repeat: iterations) {
      stringBasedIds[stringBasedId.id] = 1
    }

    var nestedEnumBasedIds = [NestedEnumBasedNodeId.Id: Int]()
    var nestedEnumBasedId = NestedEnumBasedNodeId(id: .custom("AA"), isFixed: false)
    for i in 1 ... hierarchyDepth {
      let child = NestedEnumBasedNodeId(id: .custom("B\(i)"), isFixed: false)
      nestedEnumBasedId = nestedEnumBasedId.join(with: child, suffix: "1")
    }
    let nestedEnumIdTime = ChouTiTest.measure(repeat: iterations) {
      nestedEnumBasedIds[nestedEnumBasedId.id] = 1
    }

    var nestedEnumId2BasedIds = [NestedEnumBasedNodeId2: Int]()
    var nestedEnumId2BasedId = NestedEnumBasedNodeId2(id: .custom("AA"), isFixed: false)
    for i in 1 ... hierarchyDepth {
      let child = NestedEnumBasedNodeId2(id: .custom("B\(i)"), isFixed: false)
      nestedEnumId2BasedId = nestedEnumId2BasedId.join(with: child, suffix: "1")
    }
    let nestedEnumId2Time = ChouTiTest.measure(repeat: iterations) {
      nestedEnumId2BasedIds[nestedEnumId2BasedId] = 1
    }

    var linkedListBasedIds = [LinkedListBasedNodeId: Int]()
    var linkedListBasedId = LinkedListBasedNodeId(id: "AA", isFixed: false)
    for i in 1 ... hierarchyDepth {
      let child = LinkedListBasedNodeId(id: "B\(i)", isFixed: false)
      linkedListBasedId = linkedListBasedId.join(with: child, suffix: "1")
    }
    let linkedListIdTime = ChouTiTest.measure(repeat: iterations) {
      linkedListBasedIds[linkedListBasedId] = 1
    }

    let stringMs = stringIdTime * 1000
    let nestedEnumMs = nestedEnumIdTime * 1000
    let nestedEnumId2Ms = nestedEnumId2Time * 1000
    let linkedListMs = linkedListIdTime * 1000

    print("""
    ComposeNodeId Hashing Performance Comparison:
    • String-based:     \(String(format: "%.2f", stringMs)) ms
    • NestedEnum-based: \(String(format: "%.2f", nestedEnumMs)) ms
    • NestedEnum2-based: \(String(format: "%.2f", nestedEnumId2Ms)) ms
    • LinkedList-based: \(String(format: "%.2f", linkedListMs)) ms
    """)
  }
}
