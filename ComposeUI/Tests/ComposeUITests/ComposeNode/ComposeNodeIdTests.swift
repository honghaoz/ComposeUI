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
    // given: a standard id for the color node
    let id = ComposeNodeId.standard(.color)

    // then: the id string is the short code
    expect(id.id) == "C"
  }

  func test_standard_allCases() {
    // when: making the standard id of each case
    let ids = StandardComposeNodeId.allCases.map { ComposeNodeId.standard($0) }

    // then: each id has its case's string
    expect(ids.map(\.id)) == ["E", "C", "TL", "TV", "B", "V", "L", "SUI", "G", "DS", "IS", "S", "F", "P", "O", "OV", "UL", "VS", "HS", "ZS", "CV"]
  }

  func test_object_isTheKindsCodeAndTheObjectsAddress() {
    // given: an object
    let object = NSObject()
    let address = String(UInt(bitPattern: ObjectIdentifier(object)), radix: 36)

    // then: its id for a kind is the kind's code, a colon and the object's address in base 36
    expect(ComposeNodeId.object(object, kind: .layer).id) == "L:\(address)"
    expect(ComposeNodeId.object(object, kind: .view).id) == "V:\(address)"
  }

  func test_object_isTheSameForAnObject_andDiffersForAnother() {
    // given: two objects
    let object = NSObject()
    let otherObject = NSObject()

    // then: the ids of an object are equal and hash the same, and the ids of the other object differ
    expect(ComposeNodeId.object(object, kind: .layer)) == ComposeNodeId.object(object, kind: .layer)
    expect(ComposeNodeId.object(object, kind: .layer).hashValue) == ComposeNodeId.object(object, kind: .layer).hashValue
    expect(ComposeNodeId.object(object, kind: .layer)) != ComposeNodeId.object(otherObject, kind: .layer)
  }

  func test_object_hashMatchesACustomIdOfItsString() {
    // given: an object's id
    let id = ComposeNodeId.object(NSObject(), kind: .layer)

    // when: making a custom id of its string
    let customId = ComposeNodeId.custom(id.id)

    // then: the ids are equal and hash the same
    expect(id) == customId
    expect(id.hashValue) == customId.hashValue
  }

  func test_object_takesNoAllocation() {
    // given: an object, and a body that makes its id into a variable outside the body, so that an optimized build can't
    // drop the work, run once already, since a first run can also allocate what the runtime makes on first use, such as
    // type metadata
    let object = NSObject()
    var id: ComposeNodeId?
    let body = {
      id = ComposeNodeId.object(object, kind: .layer)
    }
    _ = AllocationCounter.count(body)

    // when: counting the allocations of the body
    let allocations = AllocationCounter.count(body)

    // then: the id fits in a small string, which takes no allocation
    expect(allocations) == 0
    expect(id) == ComposeNodeId.object(object, kind: .layer)
  }

  func test_standard_joinedHashMatchesDirectId() {
    for standardId in StandardComposeNodeId.allCases {
      // given: a standard id joined with a child, which hashes on from the standard id's hash
      let joinedId = ComposeNodeId.standard(standardId).join(with: .custom("child"))

      // when: making a custom id of the joined string
      let directId = ComposeNodeId.custom(joinedId.id)

      // then: the ids are equal and hash the same
      expect(joinedId) == directId
      expect(joinedId.hashValue) == directId.hashValue
    }
  }

  func test_custom_standardIdString() {
    // given: an assertion handler that records the messages
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: making a custom id with a standard id's string
    let id = ComposeNodeId.custom("TL")

    // then: it asserts, and the id gets a unique string instead
    expect(assertionMessages) == ["[ComposeUI] Custom id conflict with standard id: TL, please use a unique id."]
    expect(id.id.hasPrefix("TL-")) == true
    expect(id) != ComposeNodeId.standard(.label)

    // when: making a custom id with a string that no standard id has
    let otherId = ComposeNodeId.custom("T")

    // then: it doesn't assert, and the id keeps its string
    expect(assertionMessages.count) == 1
    expect(otherId.id) == "T"
  }

  func test_identity_ignoresIsFixed() {
    // given: two custom ids with the same string but different isFixed flags
    let nonFixed = ComposeNodeId.custom("x", isFixed: false)
    let fixed = ComposeNodeId.custom("x", isFixed: true)

    // then: the ids are equal and hash the same
    expect(nonFixed) == fixed
    expect(nonFixed.hashValue) == fixed.hashValue

    // when: both ids are used as dictionary keys
    var map: [ComposeNodeId: Int] = [:]
    map[nonFixed] = 1
    map[fixed] = 2

    // then: they collide into a single entry
    expect(map.count) == 1
    expect(map[nonFixed]) == 2

    // then: different id strings remain distinct
    expect(ComposeNodeId.custom("x")) != ComposeNodeId.custom("y")
  }

  func test_custom() {
    // given: a custom id
    let id = ComposeNodeId.custom("test")

    // then: the id string matches
    expect(id.id) == "test"

    // given: a parent id
    let parentId = ComposeNodeId.custom("parent")

    // when: joining without a suffix
    do {
      let childId = parentId.join(with: id)

      // then: the joined id concatenates parent and child ids
      expect(childId.id) == "parent|test"
    }

    // when: joining with a suffix
    do {
      let childId = parentId.join(with: id, suffix: "suffix")

      // then: the joined id includes the suffix
      expect(childId.id) == "parent|suffix|test"
    }
  }

  func test_join_hashMatchesDirectId() {
    // given: a parent id and a child id
    let parentId = ComposeNodeId.custom("parent")
    let childId = ComposeNodeId.custom("test")

    // when: joining without a suffix
    do {
      let joinedId = parentId.join(with: childId)
      let directId = ComposeNodeId.custom("parent|test")

      // then: the joined id equals and hashes the same as the direct id
      expect(joinedId) == directId
      expect(joinedId.hashValue) == directId.hashValue

      // when: both ids are used as dictionary keys
      var map: [ComposeNodeId: Int] = [:]
      map[joinedId] = 1
      map[directId] = 2

      // then: they collide into a single entry
      expect(map.count) == 1
      expect(map[joinedId]) == 2
    }

    // when: joining with a suffix
    do {
      let joinedId = parentId.join(with: childId, suffix: "suffix")
      let directId = ComposeNodeId.custom("parent|suffix|test")

      // then: the joined id equals and hashes the same as the direct id
      expect(joinedId) == directId
      expect(joinedId.hashValue) == directId.hashValue
    }
  }

  func test_join_deepHashMatchesDirectId() {
    // given: a root id
    var id = ComposeNodeId.custom("root")
    var expectedId = "root"

    // when: joining 20 levels of children with suffixes
    for index in 0 ..< 20 {
      let childId = ComposeNodeId.custom("child-\(index)")
      id = id.join(with: childId, suffix: "suffix-\(index)")
      expectedId += "|suffix-\(index)|child-\(index)"
    }

    // then: the deep joined id equals and hashes the same as the direct id
    let directId = ComposeNodeId.custom(expectedId)
    expect(id) == directId
    expect(id.hashValue) == directId.hashValue
  }

  func test_join_keepsEachPiecesBytes_andHashesAsADirectId() {
    // then: joins write into the string's storage on the systems that the tests run on, keep each piece's bytes, and
    // hash as an id made directly of those bytes
    expectJoinsToKeepEachPiecesBytes_andHashAsADirectId()
  }

  func test_join_inTemporaryBuffer_keepsEachPiecesBytes_andHashesAsADirectId() {
    // given: joins that write into a temporary buffer, as on systems before macOS 11, iOS 14 and tvOS 14
    ComposeNodeId.joinsInTemporaryBuffer = true
    defer {
      ComposeNodeId.joinsInTemporaryBuffer = false
    }

    // then: the joins write into the temporary buffer, keep each piece's bytes, and hash as an id made directly of those
    // bytes
    expectJoinsToKeepEachPiecesBytes_andHashAsADirectId()
  }

  func test_join_allocatesOnlyForAnIdPastTheInlineLimit() {
    // then: joins write into the string's storage on the systems that the tests run on, and allocate only for an id past
    // the 15 bytes that a string stores inline
    expectJoinsToAllocateOnlyForAnIdPastTheInlineLimit()
  }

  func test_join_inTemporaryBuffer_allocatesOnlyForAnIdPastTheInlineLimit() {
    // given: joins that write into a temporary buffer, as on systems before macOS 11, iOS 14 and tvOS 14
    ComposeNodeId.joinsInTemporaryBuffer = true
    defer {
      ComposeNodeId.joinsInTemporaryBuffer = false
    }

    // then: the joins write into the temporary buffer, and allocate only for an id past the 15 bytes that a string
    // stores inline
    expectJoinsToAllocateOnlyForAnIdPastTheInlineLimit()
  }

  func test_join_idsOfBridgedStrings_allocatesOnlyForTheJoinedId() {
    // given: ids of strings bridged from `NSString`, which don't store contiguous UTF-8, and bodies that join each with
    // a native id into a variable outside the bodies, run once already, since a first run can also allocate what the
    // runtime makes on first use, such as type metadata
    let bridgedParent = NSString(string: "a parent id from Objective-C, naïve") as String
    let bridgedChild = NSString(string: "a child id from Objective-C, naïve") as String
    expect(bridgedParent.isContiguousUTF8) == false
    expect(bridgedChild.isContiguousUTF8) == false
    let bridgedParentId = ComposeNodeId.custom(bridgedParent)
    let bridgedChildId = ComposeNodeId.custom(bridgedChild)
    let nativeId = ComposeNodeId.custom("native")
    var joinedId: ComposeNodeId?
    let joinBridgedParent = {
      joinedId = bridgedParentId.join(with: nativeId, suffix: "1")
    }
    let joinBridgedChild = {
      joinedId = nativeId.join(with: bridgedChildId, suffix: "1")
    }
    _ = AllocationCounter.count(joinBridgedParent)
    _ = AllocationCounter.count(joinBridgedChild)

    // when: counting the allocations of each join
    let bridgedParentAllocations = AllocationCounter.count(joinBridgedParent)
    let bridgedChildAllocations = AllocationCounter.count(joinBridgedChild)

    // then: each join allocates only the joined id's storage, since making an id copies a bridged string into contiguous
    // storage once, where each join would otherwise copy it
    expect(bridgedParentAllocations) == 1
    expect(bridgedChildAllocations) == 1
    expect(joinedId?.id) == "native|1|a child id from Objective-C, naïve"
  }

  func test_custom_fixed() {
    // given: a fixed custom id
    let id = ComposeNodeId.custom("test", isFixed: true)

    // then: the id string matches
    expect(id.id) == "test"

    // given: a non-fixed parent id
    let parentId = ComposeNodeId.custom("parent", isFixed: false)

    // when: joining without a suffix
    do {
      let childId = parentId.join(with: id)

      // then: the fixed id is not prefixed by the parent
      expect(childId.id) == "test"
    }

    // when: joining with a suffix
    do {
      let childId = parentId.join(with: id, suffix: "suffix")

      // then: the fixed id is not prefixed by the parent
      expect(childId.id) == "test"
    }
  }

  // MARK: - Helpers

  /// Expects joins to keep each piece's bytes, and to hash as an id made directly of those bytes.
  private func expectJoinsToKeepEachPiecesBytes_andHashAsADirectId(file: StaticString = #filePath, line: UInt = #line) {
    // given: pieces whose joined ids take 15 and 16 bytes, the most and the least that a string stores inline and on the
    // heap, with and without a suffix, pieces with a decomposed character, which `String`'s `==` matches with its
    // precomposed form, and characters of several bytes, empty pieces, long pieces, and pieces bridged from `NSString`,
    // which don't store contiguous UTF-8
    let longPiece = String(repeating: "a", count: 5000)
    let bridgedParent = NSString(string: "naïve") as String
    let bridgedChild = NSString(string: "child 👋🏽") as String
    expect(bridgedParent.isContiguousUTF8, file: file, line: line) == false
    expect(bridgedChild.isContiguousUTF8, file: file, line: line) == false
    let cases: [(parent: String, suffix: String?, child: String)] = [
      ("AAAA", "1", "BBBBBBBB"),
      ("AAAA", "1", "BBBBBBBBB"),
      ("AAAAAAA", nil, "BBBBBBB"),
      ("AAAAAAA", nil, "BBBBBBBB"),
      ("e\u{301}", "２", "👋🏽"),
      ("", "", ""),
      (longPiece, longPiece, longPiece),
      (bridgedParent, "1", bridgedChild),
    ]
    let temporaryBufferJoinCount = ComposeNodeId.temporaryBufferJoinCount

    for (parent, suffix, child) in cases {
      // when: joining the child's id to the parent's id, with the suffix, if any
      let joinedId = ComposeNodeId.custom(parent).join(with: .custom(child), suffix: suffix)

      // then: the joined id has the bytes of each piece, with a separator between each, and equals and hashes the same
      // as an id made directly of those bytes
      let expectedId = suffix.map { "\(parent)|\($0)|\(child)" } ?? "\(parent)|\(child)"
      expect(Array(joinedId.id.utf8), file: file, line: line) == Array(expectedId.utf8)
      expect(joinedId, file: file, line: line) == ComposeNodeId.custom(expectedId)
      expect(joinedId.hashValue, file: file, line: line) == ComposeNodeId.custom(expectedId).hashValue
    }

    // then: each join went the way that `joinsInTemporaryBuffer` chose, which the ids can't tell, since both ways make
    // the same ids
    let temporaryBufferJoins = ComposeNodeId.temporaryBufferJoinCount - temporaryBufferJoinCount
    expect(temporaryBufferJoins, file: file, line: line) == (ComposeNodeId.joinsInTemporaryBuffer ? cases.count : 0)
  }

  /// Expects joins to allocate nothing for an id of 15 bytes, which a string stores inline, and once, for its storage,
  /// for an id of 16 bytes.
  private func expectJoinsToAllocateOnlyForAnIdPastTheInlineLimit(file: StaticString = #filePath, line: UInt = #line) {
    // given: a parent id and child ids whose joined ids take 15 and 16 bytes, and bodies that join them into a variable
    // outside the bodies, so that an optimized build can't drop the work, run once already, since a first run can also
    // allocate what the runtime makes on first use, such as type metadata
    let parentId = ComposeNodeId.custom("AAAA")
    let shortChildId = ComposeNodeId.custom("BBBBBBBB")
    let longChildId = ComposeNodeId.custom("BBBBBBBBB")
    var joinedId: ComposeNodeId?
    let joinShort = {
      joinedId = parentId.join(with: shortChildId, suffix: "1")
    }
    let joinLong = {
      joinedId = parentId.join(with: longChildId, suffix: "1")
    }
    _ = AllocationCounter.count(joinShort)
    _ = AllocationCounter.count(joinLong)
    let temporaryBufferJoinCount = ComposeNodeId.temporaryBufferJoinCount

    // when: counting the allocations of each join
    let shortAllocations = AllocationCounter.count(joinShort)
    let longAllocations = AllocationCounter.count(joinLong)

    // then: the 15-byte id fits in a small string, which takes no allocation, and the 16-byte id takes one, for its
    // storage
    expect(shortAllocations, file: file, line: line) == 0
    expect(longAllocations, file: file, line: line) == 1
    expect(joinedId?.id, file: file, line: line) == "AAAA|1|BBBBBBBBB"

    // then: both joins went the way that `joinsInTemporaryBuffer` chose
    let temporaryBufferJoins = ComposeNodeId.temporaryBufferJoinCount - temporaryBufferJoinCount
    expect(temporaryBufferJoins, file: file, line: line) == (ComposeNodeId.joinsInTemporaryBuffer ? 2 : 0)
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
    // given: iteration and depth settings for creating deep hierarchies
    let hierarchyDepth = 10
    let iterations = 10000

    // when: measuring deep id creation with each implementation
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

    // then: print the performance comparison
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
    // given: iteration and depth settings for hashing deep hierarchies
    let hierarchyDepth = 10
    let iterations = 10000

    // when: building a deep id and measuring hashing for each implementation
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

    // then: print the performance comparison
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
