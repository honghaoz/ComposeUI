//
//  ComposeNodeId+JoinCacheTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/26/26.
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

class ComposeNodeId_JoinCacheTests: XCTestCase {

  // MARK: - Joins

  func test_cachedJoin_withoutACurrentCache_joinsAsJoinDoes() {
    for parent in Constants.parents {
      for child in Constants.children {
        for (suffix, suffixString) in Constants.suffixes {
          // when: joining the ids without a current cache
          let id = parent.cachedJoin(with: child, suffix: suffix)

          // then: the id is the one that `join(with:suffix:)` makes with the suffix's string
          expectSameId(id, as: parent.join(with: child, suffix: suffixString))
        }
      }
    }
  }

  func test_cachedJoin_withACache_joinsAsJoinDoes_inEachPass() {
    // given: a cache
    let cache = ComposeNodeId.JoinCache()

    // when: joining the ids in three passes: the first sizes the cache, the second keeps the joins, and the third finds
    // them
    for pass in 1 ... 3 {
      var ids: [ComposeNodeId] = []
      cache.performAsCurrent {
        for parent in Constants.parents {
          for child in Constants.children {
            for (suffix, _) in Constants.suffixes {
              ids.append(parent.cachedJoin(with: child, suffix: suffix))
            }
          }
        }
      }

      // then: each id is the one that `join(with:suffix:)` makes with the suffix's string
      var expectedIds: [ComposeNodeId] = []
      for parent in Constants.parents {
        for child in Constants.children {
          for (_, suffixString) in Constants.suffixes {
            expectedIds.append(parent.join(with: child, suffix: suffixString))
          }
        }
      }
      expect(ids.count, "pass \(pass)") == expectedIds.count
      for (id, expectedId) in zip(ids, expectedIds) {
        expectSameId(id, as: expectedId)
      }
    }
  }

  func test_cachedJoin_fixedChild_givesTheChildsIdWithoutKeepingIt() {
    // given: a cache with entries after a pass, a parent id, and a fixed child id
    let cache = ComposeNodeId.JoinCache()
    let parent = ComposeNodeId.custom("parent")
    cache.performAsCurrent {
      _ = parent.cachedJoin(with: .custom("child"))
    }
    expect(cache.capacityForTesting) == ComposeNodeId.JoinCache.minimumCapacityForTesting
    let fixedChild = ComposeNodeId.custom("fixed child", isFixed: true)

    // when: joining the fixed child's id without a current cache, and with the cache in two passes
    let idWithoutCache = parent.cachedJoin(with: fixedChild, suffix: .index(1))
    var idsWithCache: [ComposeNodeId] = []
    for _ in 0 ..< 2 {
      cache.performAsCurrent {
        idsWithCache.append(parent.cachedJoin(with: fixedChild, suffix: .index(1)))
      }
    }

    // then: each join gives the fixed child's id, and the cache keeps none of them
    expectSameId(idWithoutCache, as: fixedChild)
    expect(idsWithCache.count) == 2
    for id in idsWithCache {
      expectSameId(id, as: fixedChild)
    }
    expect(cache.joinCountInEntriesForTesting) == 0
  }

  func test_cachedJoin_keepsTheJoinsFromTheSecondPass_andGivesThemFromTheThird() {
    // given: a cache, and joins whose ids are past the 15 bytes that a string stores inline, so that each joined id is in
    // storage of its own, made in a pass
    let cache = ComposeNodeId.JoinCache()
    let parent = ComposeNodeId.custom("a parent id past the inline limit")
    let children = (0 ..< 10).map { ComposeNodeId.custom("child \($0)") }
    var ids = [ComposeNodeId?](repeating: nil, count: children.count)
    let pass = {
      cache.performAsCurrent {
        for (index, child) in children.enumerated() {
          ids[index] = parent.cachedJoin(with: child, suffix: .index(index))
        }
      }
    }
    let expectedIds = children.enumerated().map { index, child in parent.join(with: child, suffix: "\(index)") }

    // when: making the joins in a first pass
    pass()

    // then: the ids are the joined ids, and the cache, which has no entries during its first pass, has entries for twice
    // the pass's joins after it, keeping none of the joins
    for (id, expectedId) in zip(ids, expectedIds) {
      expectSameId(id, as: expectedId)
    }
    expect(cache.capacityForTesting) == 32
    expect(cache.joinCountInEntriesForTesting) == 0

    // when: making the joins in a second pass
    pass()

    // then: the ids are the joined ids, which the cache keeps
    for (id, expectedId) in zip(ids, expectedIds) {
      expectSameId(id, as: expectedId)
    }
    expect(cache.joinCountInEntriesForTesting) == children.count
    let keptAddresses = ids.map { $0?.id.storageAddress }
    expect(keptAddresses.contains(nil)) == false

    // when: making the joins in a third pass
    pass()

    // then: each join gives the id that the cache kept
    expect(ids.map { $0?.id.storageAddress }) == keptAddresses
  }

  func test_cachedJoin_joinThatTheCacheKeeps_takesNoAllocation() {
    // given: a cache that keeps a join whose id is past the inline limit, after two passes of it, two other joins, and
    // a body that makes a pass of one join, run once with one of the other joins already, since a first run can also
    // allocate what the runtime makes on first use, such as type metadata
    let cache = ComposeNodeId.JoinCache()
    let parent = ComposeNodeId.custom("a parent id past the inline limit")
    let keptChild = ComposeNodeId.custom("kept child")
    let otherChildren = [ComposeNodeId.custom("other child 1"), ComposeNodeId.custom("other child 2")]
    var id: ComposeNodeId?
    func allocationsOfAPass(joining child: ComposeNodeId) -> Int? {
      AllocationCounter.count {
        cache.performAsCurrent {
          id = parent.cachedJoin(with: child)
        }
      }
    }
    _ = allocationsOfAPass(joining: keptChild)
    _ = allocationsOfAPass(joining: keptChild)
    _ = allocationsOfAPass(joining: otherChildren[0])

    // when: a pass of the kept join
    let keptJoinAllocations = allocationsOfAPass(joining: keptChild)

    // then: the cache gives the kept id, without allocating
    expect(keptJoinAllocations) == 0
    expect(id?.id) == "a parent id past the inline limit|kept child"

    // when: a pass of the other join that the cache doesn't keep
    let otherJoinAllocations = allocationsOfAPass(joining: otherChildren[1])

    // then: the join allocates its id once
    expect(otherJoinAllocations) == 1
    expect(id?.id) == "a parent id past the inline limit|other child 2"
  }

  func test_cachedJoin_childIdOfTheSameBytesInOtherStorage_givesTheKeptId() {
    // given: a cache that keeps the join of a child id past the inline limit, after two passes, and a child id of the
    // same bytes in other storage, as a refresh makes a node's id again
    let cache = ComposeNodeId.JoinCache()
    let parent = ComposeNodeId.standard(.vStack)
    let child = ComposeNodeId.custom(String(repeating: "c", count: 20))
    let childOfTheSameBytes = ComposeNodeId.custom(String(repeating: "c", count: 20))
    expect(child.id.storageAddress) != childOfTheSameBytes.id.storageAddress
    var keptId: ComposeNodeId?
    for _ in 0 ..< 2 {
      cache.performAsCurrent {
        keptId = parent.cachedJoin(with: child, suffix: .index(3))
      }
    }

    // when: joining the other child id, counting the allocations
    var id: ComposeNodeId?
    let allocations = AllocationCounter.count {
      cache.performAsCurrent {
        id = parent.cachedJoin(with: childOfTheSameBytes, suffix: .index(3))
      }
    }

    // then: the join gives the kept id, without allocating
    expect(allocations) == 0
    expect(id?.id.storageAddress) == keptId?.id.storageAddress
    expectSameId(id, as: parent.join(with: childOfTheSameBytes, suffix: "3"))
  }

  func test_cachedJoin_joinsThatDifferInOnePiece_giveTheirOwnIds() {
    // given: joins that differ from the first in one piece each: the parent's id, the parent's fixedness, which a key
    // doesn't tell apart, the child's id, the suffix's index, no suffix, a text suffix of the same bytes as the index,
    // and another text suffix, which a key doesn't tell apart
    let parent = ComposeNodeId.custom("parent")
    let child = ComposeNodeId.custom("a child id past the inline limit")
    let joins: [(parent: ComposeNodeId, child: ComposeNodeId, suffix: ComposeNodeId.JoinSuffix, suffixString: String?)] = [
      (parent, child, .index(1), "1"),
      (.custom("another parent"), child, .index(1), "1"),
      (.custom("parent", isFixed: true), child, .index(1), "1"),
      (parent, .custom("another child id past the inline limit"), .index(1), "1"),
      (parent, child, .index(2), "2"),
      (parent, child, .none, nil),
      (parent, child, .text("1"), "1"),
      (parent, child, .text("2"), "2"),
    ]
    let cache = ComposeNodeId.JoinCache()

    for pass in 1 ... 3 {
      // when: making the joins in a pass
      var ids: [ComposeNodeId] = []
      cache.performAsCurrent {
        ids = joins.map { $0.parent.cachedJoin(with: $0.child, suffix: $0.suffix) }
      }

      // then: each join gives the id that `join(with:suffix:)` makes of its pieces, in the passes that keep and find
      // the joins too
      expect(ids.count, "pass \(pass)") == joins.count
      for (join, id) in zip(joins, ids) {
        expectSameId(id, as: join.parent.join(with: join.child, suffix: join.suffixString))
      }
    }
  }

  func test_cachedJoin_joinOfAFullBucket_replacesTheJoinUsedLongestAgo() {
    // given: five joins of one bucket in a cache of the fewest entries, whose ids are past the inline limit, so that
    // each join that the cache doesn't give allocates its id
    let parent = ComposeNodeId.custom("a parent id past the inline limit")
    let children = childrenOfOneBucket(count: ComposeNodeId.JoinCache.bucketSizeForTesting + 1, parent: parent)
    let cache = ComposeNodeId.JoinCache()
    func makePass(joining children: [ComposeNodeId]) {
      cache.performAsCurrent {
        for child in children {
          _ = parent.cachedJoin(with: child)
        }
      }
    }
    func allocationsOfAPass(joining child: ComposeNodeId) -> Int? {
      AllocationCounter.count {
        cache.performAsCurrent {
          _ = parent.cachedJoin(with: child)
        }
      }
    }
    let (first, second, third, fourth, fifth) = (children[0], children[1], children[2], children[3], children[4])

    // given: a pass of the first four joins, which sizes the cache to the fewest entries, another, which keeps them in
    // the bucket's entries, and a pass of all but the first, after which the cache used the first longest ago
    makePass(joining: [first, second, third, fourth])
    expect(cache.capacityForTesting) == ComposeNodeId.JoinCache.minimumCapacityForTesting
    makePass(joining: [first, second, third, fourth])
    makePass(joining: [second, third, fourth])

    // when: a pass of the fifth join
    let fifthJoinAllocations = allocationsOfAPass(joining: fifth)

    // then: the fifth join allocates its id, which the cache keeps in place of the first join, and the cache gives the
    // other joins without allocating, while the first join allocates its id again
    expect(fifthJoinAllocations) == 1
    expect([second, third, fourth, fifth].map { allocationsOfAPass(joining: $0) }) == [0, 0, 0, 0]
    expect(allocationsOfAPass(joining: first)) == 1
  }

  // MARK: - Sizes

  func test_finishPass_growsRightAfterAPassOfMoreJoinsThanHalfTheEntries() {
    // given: a cache with entries for passes of 8 joins
    let cache = ComposeNodeId.JoinCache()
    makePass(of: 8, in: cache)
    expect(cache.capacityForTesting) == 16

    // when: a pass of 8 joins, which takes half the entries
    makePass(of: 8, in: cache)

    // then: the cache keeps its entries, with the pass's joins
    expect(cache.capacityForTesting) == 16
    expect(cache.joinCountInEntriesForTesting) > 0

    // when: a pass of 9 joins
    makePass(of: 9, in: cache)

    // then: the cache grows to twice the pass's joins, rounded up to a power of two, without the joins it kept
    expect(cache.capacityForTesting) == 32
    expect(cache.joinCountInEntriesForTesting) == 0
  }

  func test_finishPass_shrinksOnlyAfterAWholeRoundOfPassesOfFarFewerJoins() {
    // given: a cache that grew for a pass of 100 joins, and the number of passes that it decides to shrink after
    let cache = ComposeNodeId.JoinCache()
    makePass(of: 100, in: cache)
    expect(cache.capacityForTesting) == 256
    let passesPerDecision = ComposeNodeId.JoinCache.passesPerShrinkDecisionForTesting

    // when: passes of 10 joins, which need far fewer entries, until the decision of the round of the pass of 100 joins
    for _ in 1 ..< passesPerDecision {
      makePass(of: 10, in: cache)
    }

    // then: the cache keeps its size, since the round had the pass of 100 joins
    expect(cache.capacityForTesting) == 256

    // when: passes of 10 joins until the decision of the next round
    for _ in 1 ..< passesPerDecision {
      makePass(of: 10, in: cache)
    }

    // then: the cache keeps its size until the decision
    expect(cache.capacityForTesting) == 256

    // when: the next round's last pass
    makePass(of: 10, in: cache)

    // then: the cache shrinks to twice the round's most joins, rounded up to a power of two
    expect(cache.capacityForTesting) == 32
  }

  func test_finishPass_passesOfDifferentNumbersOfJoins_keepTheEntriesForTheMost() {
    // given: a cache that keeps the joins of a pass of 100 joins, and the number of passes that it decides to shrink after
    let cache = ComposeNodeId.JoinCache()
    makePass(of: 100, in: cache)
    makePass(of: 100, in: cache)
    expect(cache.capacityForTesting) == 256
    let keptJoinCount = cache.joinCountInEntriesForTesting
    let passesPerDecision = ComposeNodeId.JoinCache.passesPerShrinkDecisionForTesting

    // when: passes of the 100 joins between passes of 5 of them, as a view's passes that show the screen are between
    // passes that prefetch a row, for several rounds
    for _ in 0 ..< passesPerDecision * 3 {
      makePass(of: 100, in: cache)
      makePass(of: 5, in: cache)
    }

    // then: the cache keeps its size and its entries
    expect(cache.capacityForTesting) == 256
    expect(cache.joinCountInEntriesForTesting) == keptJoinCount
  }

  func test_finishPass_afterAWholeRoundOfPassesWithoutJoins_removesTheEntries() {
    // given: a cache with entries for passes of 5 joins, and the number of passes that it decides to shrink after
    let cache = ComposeNodeId.JoinCache()
    makePass(of: 5, in: cache)
    expect(cache.capacityForTesting) == 16
    let passesPerDecision = ComposeNodeId.JoinCache.passesPerShrinkDecisionForTesting

    // when: passes without joins until the decision of the round of the pass of 5 joins
    for _ in 1 ..< passesPerDecision {
      makePass(of: 0, in: cache)
    }

    // then: the cache keeps its entries, since the round had the pass of 5 joins
    expect(cache.capacityForTesting) == 16

    // when: passes without joins for the next round
    for _ in 0 ..< passesPerDecision {
      makePass(of: 0, in: cache)
    }

    // then: the cache removes its entries
    expect(cache.capacityForTesting) == 0
    expect(cache.joinCountInEntriesForTesting) == 0
  }

  func test_finishPass_keepsAtMostTheMostEntries() {
    // given: a cache, and a number of joins that is more than half the most entries
    let cache = ComposeNodeId.JoinCache()
    let maximumCapacity = ComposeNodeId.JoinCache.maximumCapacityForTesting
    let joinCount = maximumCapacity / 2 + 1

    // when: a pass of that many joins
    makePass(of: joinCount, in: cache)

    // then: the cache has the most entries
    expect(cache.capacityForTesting) == maximumCapacity

    // when: another pass of the joins
    makePass(of: joinCount, in: cache)

    // then: the cache keeps its entries, with the pass's joins, instead of replacing them with entries of the same number
    expect(cache.capacityForTesting) == maximumCapacity
    expect(cache.joinCountInEntriesForTesting) > 0
  }

  // MARK: - Current Cache

  func test_performAsCurrent_withinAnotherCachesPass_joinsWithTheInnerCacheUntilItReturns() {
    // given: two caches with entries after a pass each, and a parent id
    let outerCache = ComposeNodeId.JoinCache()
    let innerCache = ComposeNodeId.JoinCache()
    let parent = ComposeNodeId.custom("parent")
    outerCache.performAsCurrent {
      _ = parent.cachedJoin(with: .custom("child"))
    }
    innerCache.performAsCurrent {
      _ = parent.cachedJoin(with: .custom("child"))
    }

    // when: joining in a pass of the outer cache, before, within and after a pass of the inner cache, and joining after
    // the outer cache's pass
    let result = outerCache.performAsCurrent {
      _ = parent.cachedJoin(with: .custom("before"))
      innerCache.performAsCurrent {
        _ = parent.cachedJoin(with: .custom("within"))
      }
      _ = parent.cachedJoin(with: .custom("after"))
      return "result"
    }
    _ = parent.cachedJoin(with: .custom("outside"))

    // then: the inner cache keeps the join of its pass, the outer cache keeps the joins before and after it, neither
    // keeps the join outside, and the outer cache's pass returns the body's result
    expect(innerCache.joinCountInEntriesForTesting) == 1
    expect(outerCache.joinCountInEntriesForTesting) == 2
    expect(result) == "result"
  }

  // MARK: - Helpers

  private enum Constants {

    /// Parent ids: a standard id, custom ids within and past the inline limit, and a fixed id.
    static let parents: [ComposeNodeId] = [
      .standard(.vStack),
      .custom("parent"),
      .custom("a parent id past the inline limit"),
      .custom("parent", isFixed: true),
    ]

    /// Child ids within and past the inline limit.
    static let children: [ComposeNodeId] = [
      .custom("child"),
      .custom("a child id past the inline limit"),
    ]

    /// Suffixes, each with the string that `join(with:suffix:)` takes for it.
    static let suffixes: [(suffix: ComposeNodeId.JoinSuffix, string: String?)] = [
      (.none, nil),
      (.index(0), "0"),
      (.index(12), "12"),
      (.index(-3), "-3"),
      (.index(Int.max), "\(Int.max)"),
      (.index(Int.min), "\(Int.min)"),
      (.text("O"), "O"),
    ]
  }

  /// Expects an id to be another id: the same bytes, hash and fixedness.
  private func expectSameId(_ id: ComposeNodeId?, as expectedId: ComposeNodeId, file: StaticString = #filePath, line: UInt = #line) {
    expect(id.map { Array($0.id.utf8) }, file: file, line: line) == Array(expectedId.id.utf8)
    expect(id?.cachedHash, file: file, line: line) == expectedId.cachedHash
    expect(id?.isFixed, file: file, line: line) == expectedId.isFixed
  }

  /// Makes a pass of a number of joins, which differ in their suffixes, in a cache.
  private func makePass(of joinCount: Int, in cache: ComposeNodeId.JoinCache) {
    cache.performAsCurrent {
      for index in 0 ..< joinCount {
        _ = ComposeNodeId.custom("parent").cachedJoin(with: .custom("child"), suffix: .index(index))
      }
    }
  }

  /// Returns child ids whose joins to a parent id without a suffix take the same bucket in a cache of the fewest entries.
  private func childrenOfOneBucket(count: Int, parent: ComposeNodeId) -> [ComposeNodeId] {
    var childrenByBucket: [Int: [ComposeNodeId]] = [:]
    for number in 0... {
      let child = ComposeNodeId.custom("child \(number)")
      let bucketStart = ComposeNodeId.JoinCache.bucketStartForTesting(
        parent: parent,
        child: child,
        suffix: .none,
        capacity: ComposeNodeId.JoinCache.minimumCapacityForTesting
      )
      childrenByBucket[bucketStart, default: []].append(child)
      if let children = childrenByBucket[bucketStart], children.count == count {
        return children
      }
    }
    return []
  }
}
