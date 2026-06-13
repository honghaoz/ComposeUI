//
//  RenderablePool.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/13/26.
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

/// A key that identifies a group of interchangeable renderables in the recycle pool.
///
/// The key combines the author-provided reuse identifier with the renderable's concrete type so that two items sharing a
/// reuse identifier but backed by different types never share a bucket. This keeps the type-erased `as!` casts in the
/// renderable update closures safe even if a reuse identifier is misused across different types.
struct ReuseKey: Hashable {

  /// The author-provided reuse identifier.
  let reuseId: String

  /// The concrete renderable type.
  let type: ObjectIdentifier
}

/// A pool that recycles renderables that removed from the renderable hierarchy so they can be reused for new items of
/// the same kind, avoiding the cost of creating (and tearing down) a renderable on every render pass.
///
/// The pool is keyed by `ReuseKey` and bounded per key so it never retains an unbounded number of off-screen renderables.
/// Renderables are reused in LIFO order so the most recently parked (and therefore warmest) renderable is handed back first.
final class RenderablePool {

  // TODO: handle memory pressure
  // TODO: handle unbounded buckets (e.g. dynamic reuse keys?)

  /// The maximum number of renderables kept per key. Excess renderables are dropped (and deallocated).
  private let maxCountPerKey: Int

  private var buckets: [ReuseKey: [Renderable]] = [:]

  /// Create a renderable pool.
  ///
  /// - Parameter maxCountPerKey: The maximum number of renderables kept per key (reuse identifier + concrete type). Default is 32.
  init(maxCountPerKey: Int = 32) {
    self.maxCountPerKey = maxCountPerKey
  }

  /// Park a renderable in the pool for later reuse.
  ///
  /// The renderable must already be detached from its parent. If the bucket for the key is full, the renderable is
  /// dropped (and deallocated once the caller releases it).
  ///
  /// - Parameters:
  ///   - renderable: The renderable to park.
  ///   - key: The reuse key.
  func enqueue(_ renderable: Renderable, key: ReuseKey) {
    var bucket = buckets[key] ?? []
    guard bucket.count < maxCountPerKey else {
      // bucket is full, drop the renderable so the pool doesn't retain off-screen renderables without bound.
      return
    }
    bucket.append(renderable)
    buckets[key] = bucket
  }

  /// Take a recycled renderable for the key, if one is available.
  ///
  /// - Parameter key: The reuse key.
  /// - Returns: A recycled renderable, or `nil` if the pool has none for the key.
  func dequeue(_ key: ReuseKey) -> Renderable? {
    guard var bucket = buckets[key], let renderable = bucket.popLast() else {
      return nil
    }
    buckets[key] = bucket
    return renderable
  }

  /// Remove all parked renderables.
  func removeAll() {
    buckets.removeAll()
  }

  /// The total number of parked renderables across all keys.
  var count: Int {
    buckets.values.reduce(0) { $0 + $1.count }
  }

  /// The number of parked renderables for a key.
  ///
  /// - Parameter key: The reuse key.
  /// - Returns: The number of parked renderables for the key.
  func count(for key: ReuseKey) -> Int {
    buckets[key]?.count ?? 0
  }
}

// MARK: - RenderItem + ReuseKey

extension RenderItem {

  /// The pool reuse key for the item, or `nil` if the item does not opt into pooling.
  ///
  /// This is only non-nil for type-erased items (`RenderableItem`) that carry both a `reuseId` and the `renderableType`
  /// captured at type-erasure time.
  var reuseKey: ReuseKey? {
    guard let reuseId, let renderableType else {
      return nil
    }
    return ReuseKey(reuseId: reuseId, type: renderableType)
  }
}
