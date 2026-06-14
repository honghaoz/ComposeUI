//
//  RenderablePoolType.swift
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

/// A reuse identifier together with the namespace it belongs to.
struct ReuseId: Hashable {

  /// The origin of a reuse identifier, used to keep framework-internal and user-provided buckets isolated.
  enum Namespace: Hashable {

    /// A reuse identifier set internally by the framework (for example by ``ColorNode``).
    case framework

    /// A reuse identifier set by the caller.
    case user
  }

  let namespace: ReuseId.Namespace

  let id: String
}

/// A pool that recycles renderables removed from the renderable hierarchy so they can be reused for new items of the
/// same kind, avoiding the cost of creating (and tearing down) a renderable on every render pass.
///
/// `ComposeView` enqueues a renderable when a renderable is removed from the renderable hierarchy. And it requests a
/// renderable when a new item of the same kind is inserted into the renderable hierarchy.
///
/// - Important: A pool is accessed on the main thread during rendering, ensure the implementation is thread-safe on main thread.
public protocol RenderablePoolType: AnyObject {

  /// Enqueue a renderable in the pool for later reuse.
  ///
  /// - Parameters:
  ///   - renderable: The renderable to enqueue.
  ///   - key: The reuse key identifying the group of interchangeable renderables.
  func enqueue(_ renderable: Renderable, key: ReuseKey)

  /// Dequeue a recycled renderable for the key, if one is available.
  ///
  /// - Parameter key: The reuse key.
  /// - Returns: A recycled renderable, or `nil` if the pool has none for the key.
  func dequeue(_ key: ReuseKey) -> Renderable?
}
