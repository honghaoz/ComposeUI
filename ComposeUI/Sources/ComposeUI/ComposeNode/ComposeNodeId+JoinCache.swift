//
//  ComposeNodeId+JoinCache.swift
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

import Foundation

extension ComposeNodeId {

  /// The suffix that a container puts between its id and a child's id when it joins them.
  enum JoinSuffix: Equatable {

    /// No suffix.
    case none

    /// The child's index, which the joined id has in decimal.
    case index(Int)

    /// A text.
    case text(String)
  }

  /// Make a `ComposeNodeId` by joining the current node's id with a child node's id, as `join(with:suffix:)` does,
  /// giving the id that the current join cache made for the same ids and suffix, if it has it.
  ///
  /// A built-in container joins the ids of its children's items with this in `render(visibleBounds:into:)`. Without a
  /// current cache, such as for a node rendered outside a `ComposeView`, it joins the ids as `join(with:suffix:)` does.
  ///
  /// - Parameters:
  ///   - childNodeId: The child node's id.
  ///   - suffix: The suffix to put between the current node's id and the child node's id.
  /// - Returns: A `ComposeNodeId`.
  func cachedJoin(with childNodeId: ComposeNodeId, suffix: JoinSuffix = .none) -> ComposeNodeId {
    if childNodeId.isFixed {
      return childNodeId
    } else if let cache = JoinCache.current.pointee {
      // the cache is used without retaining it, since `performAsCurrent(_:)` keeps it alive
      return cache._withUnsafeGuaranteedRef { cache in
        cache.join(self, with: childNodeId, suffix: suffix)
      }
    } else {
      return uncachedJoin(with: childNodeId, suffix: suffix)
    }
  }

  /// Make a `ComposeNodeId` by joining the current node's id with a child node's id that isn't fixed, with a suffix,
  /// without a cache.
  private func uncachedJoin(with childNodeId: ComposeNodeId, suffix: JoinSuffix) -> ComposeNodeId {
    switch suffix {
    case .none:
      return join(with: childNodeId)
    case .index(let index):
      return join(with: childNodeId, suffixIndex: index)
    case .text(let text):
      return join(with: childNodeId, suffix: text)
    }
  }

  /// A cache of the ids that the containers of a view's content join, which gives a container the id that it joined
  /// before for the same ids and suffix, instead of joining them again.
  ///
  /// A join makes a string, which allocates for an id past the 15 bytes that a string stores inline, and most joins of a
  /// render pass repeat joins of the pass before, since a scroll renders the same content again, and a refresh makes the
  /// same ids again.
  ///
  /// The cache is the view's, which keeps it across refreshes, and the content's root makes it current while it collects
  /// the content's items, see `performAsCurrent(_:)`. Like layout and rendering, it must be used on the main thread only.
  final class JoinCache {

    /// The cache that the content's root made current, see `performAsCurrent(_:)`.
    ///
    /// It's kept in memory that the cache manages instead of a static variable, every access to which the compiler
    /// checks at run time, and it doesn't retain the cache, which `performAsCurrent(_:)` keeps alive while it's set.
    fileprivate static let current: UnsafeMutablePointer<Unmanaged<JoinCache>?> = {
      let pointer = UnsafeMutablePointer<Unmanaged<JoinCache>?>.allocate(capacity: 1)
      pointer.initialize(to: nil)
      return pointer
    }()

    /// The keys of the entries, by the entries' indices, 0 for an empty entry, or nil while the cache has no entries.
    ///
    /// They're kept apart from the entries, so that a lookup compares the keys of a bucket, which are next to each
    /// other, before it reads an entry.
    private var keys: UnsafeMutablePointer<UInt64>?

    /// The entries, in buckets of `Constants.bucketSize` entries next to each other, or nil while the cache has no
    /// entries.
    private var entries: UnsafeMutablePointer<Entry>?

    /// The number of entries, a power of two, or 0 while the cache has no entries.
    private var capacity = 0

    /// The number of the current pass, which an entry records when it's used.
    private var pass: UInt32 = 0

    /// The number of joins in the current pass.
    private var joinCount = 0

    /// The most joins in a pass since the cache last decided whether to shrink.
    private var mostJoinCount = 0

    /// The number of passes since the cache last decided whether to shrink.
    private var passCount = 0

    deinit {
      removeEntries()
    }

    /// Makes the cache the one that containers join their items' ids with while `body` runs, and then finishes the pass.
    ///
    /// The content's root calls this around its calls of the content's `render(visibleBounds:into:)`, see
    /// `ComposeView.LayoutCacheNode`. It sets the cache back to the one set before, so that a root's call within another
    /// root's finds its own cache.
    ///
    /// - Parameter body: Collects the content's items.
    /// - Returns: What `body` returns.
    func performAsCurrent<Result>(_ body: () -> Result) -> Result {
      let previous = Self.current.pointee
      Self.current.pointee = Unmanaged.passUnretained(self)
      defer {
        Self.current.pointee = previous
        finishPass()
      }
      return withExtendedLifetime(self, body)
    }

    /// Returns the id of joining a child's id that isn't fixed to a parent's id with a suffix, the one that the cache
    /// keeps for the join if it has it, otherwise a new one, which it keeps.
    fileprivate func join(_ parent: ComposeNodeId, with child: ComposeNodeId, suffix: JoinSuffix) -> ComposeNodeId {
      joinCount += 1
      guard let keys, let entries else {
        return parent.uncachedJoin(with: child, suffix: suffix)
      }

      let key = Self.key(parent: parent, child: child, suffix: suffix)
      let bucketStart = Self.bucketStart(of: key, capacity: capacity)
      // the bucket's entries are visited with a `while` loop instead of a `for` loop over a range, which a debug build
      // steps through unspecialized code that allocates on each step
      var index = bucketStart
      while index < bucketStart + Constants.bucketSize {
        if keys[index] == key, entries[index].isJoin(of: parent, childId: child.id, suffix: suffix) {
          entries[index].pass = pass
          return entries[index].joined
        }
        index += 1
      }

      let joined = parent.uncachedJoin(with: child, suffix: suffix)
      let replacedIndex = replacedIndex(inBucketAt: bucketStart, keys: keys, entries: entries)
      keys[replacedIndex] = key
      entries[replacedIndex] = Entry(parent: parent, childId: child.id, joined: joined, suffix: suffix, pass: pass)
      return joined
    }

    /// Returns the index of the entry that a new join replaces in a bucket: an empty entry, otherwise the entry used
    /// longest ago.
    private func replacedIndex(inBucketAt bucketStart: Int, keys: UnsafeMutablePointer<UInt64>, entries: UnsafeMutablePointer<Entry>) -> Int {
      var replacedIndex = bucketStart
      var replacedAge: UInt32 = 0
      var index = bucketStart
      while index < bucketStart + Constants.bucketSize {
        guard keys[index] != 0 else {
          return index
        }

        // the pass numbers wrap around, so an entry's age is the wrapping difference
        let age = pass &- entries[index].pass
        if age > replacedAge {
          replacedIndex = index
          replacedAge = age
        }
        index += 1
      }
      return replacedIndex
    }

    /// Sizes the entries for the joins of the recent passes, and starts the next pass.
    private func finishPass() {
      // the entries grow right after a pass with more joins than they fit, and shrink only after many passes with far
      // fewer, since a view's passes differ, such as a pass that prefetches a row and the pass that shows the screen,
      // and each resize drops the entries
      mostJoinCount = max(mostJoinCount, joinCount)
      passCount += 1
      if joinCount * Constants.entriesPerJoin > capacity {
        resize(toFit: joinCount)
      } else if passCount >= Constants.passesPerShrinkDecision {
        if mostJoinCount * Constants.entriesPerJoin * Constants.shrinkFactor < capacity {
          resize(toFit: mostJoinCount)
        }
        mostJoinCount = 0
        passCount = 0
      }
      joinCount = 0
      pass &+= 1
    }

    /// Replaces the entries with empty entries sized for a number of joins in a pass, or removes them for no joins,
    /// unless the entries have that size already.
    private func resize(toFit joinCount: Int) {
      let newCapacity = joinCount == 0 ? 0 : min(max(Self.powerOfTwo(atLeast: joinCount * Constants.entriesPerJoin), Constants.minimumCapacity), Constants.maximumCapacity)
      guard newCapacity != capacity else {
        return
      }

      // the entries are dropped instead of moved to their buckets in the new table, since a resize is rare, and the next
      // pass makes them again
      removeEntries()
      guard newCapacity > 0 else {
        return
      }

      let newKeys = UnsafeMutablePointer<UInt64>.allocate(capacity: newCapacity)
      newKeys.initialize(repeating: 0, count: newCapacity)
      let newEntries = UnsafeMutablePointer<Entry>.allocate(capacity: newCapacity)
      newEntries.initialize(repeating: .empty, count: newCapacity)
      keys = newKeys
      entries = newEntries
      capacity = newCapacity
    }

    /// Removes the entries and their memory.
    private func removeEntries() {
      if let keys, let entries {
        keys.deallocate()
        entries.deinitialize(count: capacity)
        entries.deallocate()
      }
      keys = nil
      entries = nil
      capacity = 0
    }

    /// Returns the key of a join, made from the hashes of its ids and its suffix, which isn't 0.
    private static func key(parent: ComposeNodeId, child: ComposeNodeId, suffix: JoinSuffix) -> UInt64 {
      let suffixHash: UInt64
      switch suffix {
      case .none:
        suffixHash = 0
      case .index(let index):
        suffixHash = UInt64(UInt(bitPattern: index)) &+ 1
      case .text:
        // a container has few text suffixes, which an entry's comparison tells apart, so the text isn't hashed
        suffixHash = Constants.textSuffixHash
      }

      var key = parent.cachedHash ^ (child.cachedHash &* Constants.childHashMultiplier) ^ (suffixHash &* Constants.suffixHashMultiplier)
      // the low bits pick the bucket, so the high bits are mixed into them
      key ^= key >> 32
      key &*= Constants.mixingMultiplier
      key ^= key >> 29
      // a key of 0 marks an empty entry
      return key | 1
    }

    /// Returns the index of the first entry of a key's bucket.
    private static func bucketStart(of key: UInt64, capacity: Int) -> Int {
      Int(truncatingIfNeeded: key) & (capacity - 1) & ~(Constants.bucketSize - 1)
    }

    /// Returns the smallest power of two that is at least a positive value.
    private static func powerOfTwo(atLeast value: Int) -> Int {
      1 << (Int.bitWidth - (value - 1).leadingZeroBitCount)
    }

    /// A join that the cache keeps: its ids and suffix, and the id that it made.
    private struct Entry {

      /// An entry of no join, which an empty entry holds.
      static let empty = Entry(parent: .standard(.empty), childId: "", joined: .standard(.empty), suffix: .none, pass: 0)

      /// The id that the child's id was joined to.
      let parent: ComposeNodeId

      /// The child's id, which isn't fixed, since a join gives a fixed child's id as it is.
      let childId: String

      /// The joined id.
      let joined: ComposeNodeId

      /// The suffix between the ids.
      let suffix: JoinSuffix

      /// The pass that the entry was last used in.
      var pass: UInt32

      /// Returns whether the entry is of the join of a child's id that isn't fixed to a parent's id with a suffix.
      func isJoin(of parent: ComposeNodeId, childId: String, suffix: JoinSuffix) -> Bool {
        // the child's id tells most joins apart, and a child's id that a container below joined with the cache, or that
        // a node keeps, is the same string as in the pass before, which compares without reading its bytes
        self.childId == childId && self.suffix == suffix && self.parent.isSameConfiguration(as: parent)
      }
    }

    #if DEBUG
    /// The number of entries, for tests.
    var capacityForTesting: Int {
      capacity
    }

    /// The number of entries that keep a join, for tests.
    var joinCountInEntriesForTesting: Int {
      guard let keys else {
        return 0
      }
      return (0 ..< capacity).count { keys[$0] != 0 }
    }

    /// The fewest entries that the cache has when it has any, for tests.
    static var minimumCapacityForTesting: Int {
      Constants.minimumCapacity
    }

    /// The most entries that the cache has, for tests.
    static var maximumCapacityForTesting: Int {
      Constants.maximumCapacity
    }

    /// The number of passes after which the cache decides whether to shrink, for tests.
    static var passesPerShrinkDecisionForTesting: Int {
      Constants.passesPerShrinkDecision
    }

    /// The number of entries in a bucket, for tests.
    static var bucketSizeForTesting: Int {
      Constants.bucketSize
    }

    /// Returns the index of the first entry of a join's bucket in entries of a capacity, for tests.
    static func bucketStartForTesting(parent: ComposeNodeId, child: ComposeNodeId, suffix: JoinSuffix, capacity: Int) -> Int {
      bucketStart(of: key(parent: parent, child: child, suffix: suffix), capacity: capacity)
    }
    #endif

    // MARK: - Constants

    private enum Constants {

      /// The number of entries in a bucket, which a lookup compares.
      static let bucketSize = 4

      /// The number of entries for each join of a pass that the cache sizes its entries for, before rounding up to a
      /// power of two, which keeps a bucket from getting more joins than it has entries for nearly all buckets.
      static let entriesPerJoin = 2

      /// How many times fewer entries than the cache has that the joins of the recent passes need for it to shrink.
      static let shrinkFactor = 4

      /// The number of passes after which the cache decides whether to shrink, from the most joins of those passes.
      static let passesPerShrinkDecision = 64

      /// The fewest entries that the cache has when it has any.
      static let minimumCapacity = 16

      /// The most entries that the cache has, about 0.9 MB, which bounds the memory of a view that joins thousands of
      /// ids in a pass, which then finds only some of them in the cache.
      static let maximumCapacity = 8192

      /// The hash of a text suffix.
      static let textSuffixHash: UInt64 = 0x8000000000000000

      /// The multiplier of the child's hash in a key, which keeps a join's key apart from the key with the ids swapped.
      static let childHashMultiplier: UInt64 = 0x9E3779B97F4A7C15

      /// The multiplier of the suffix's hash in a key, which spreads the hashes of nearby indices.
      static let suffixHashMultiplier: UInt64 = 0xC2B2AE3D27D4EB4F

      /// The multiplier that mixes a key's bits.
      static let mixingMultiplier: UInt64 = 0xBF58476D1CE4E5B9
    }
  }
}
