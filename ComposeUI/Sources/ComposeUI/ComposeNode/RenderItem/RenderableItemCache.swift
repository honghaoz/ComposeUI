//
//  RenderableItemCache.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/14/26.
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

/// A per-node cache of a single built `RenderableItem`.
///
/// A node builds its `RenderableItem` once and reuses it across render passes through this cache, avoiding the per-pass
/// cost of constructing the typed item and erasing it (`eraseToRenderableItem()`), which allocates closures and
/// instantiates function-type metadata.
///
/// The cache holds a single entry, keyed by the id's full configuration and the frame. While scrolling, both are stable
/// (the node tree and layout are unchanged), so the cached item is returned directly. If the configuration or frame
/// changes, the item is rebuilt.
///
/// The cache is a reference stored in a value-type node, so the node's struct copies share it. This is what lets a node
/// reuse its item across render passes. Being single-slot, if one base node is copied into multiple siblings that render
/// with different configurations or frames, they overwrite each other and fall back to rebuilding (still correct, but
/// without the caching benefit). Constructing a fresh node per item (the common pattern) gives each its own cache and is
/// unaffected.
final class RenderableItemCache {

  private var cachedId: ComposeNodeId?
  private var cachedFrame: CGRect = .null
  private var cachedItem: RenderableItem?

  /// Returns the cached `RenderableItem` for the given `id` and `frame`, building and caching it on a miss.
  ///
  /// - Parameters:
  ///   - id: The item's id.
  ///   - frame: The item's frame.
  ///   - build: Builds the item on a cache miss. It is non-escaping, so it is not heap-allocated on a cache hit.
  /// - Returns: The cached item on a hit, otherwise a freshly built (and now cached) item.
  func item(id: ComposeNodeId, frame: CGRect, build: () -> RenderableItem) -> RenderableItem {
    // compare the full configuration (id string and isFixed), not `==`: `==` ignores `isFixed`, but the built item's
    // composition in the parent's `join(with:)` depends on it, so a fixed/non-fixed change for the same string must rebuild.
    if let cachedItem, let cachedId, cachedId.isSameConfiguration(as: id), cachedFrame == frame {
      return cachedItem
    }

    let item = build()
    cachedId = id
    cachedFrame = frame
    cachedItem = item
    return item
  }
}
