//
//  ComposeView+InPlaceReuse.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/18/26.
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

extension ComposeView {

  /// The reusable views that the removals of a render pass leave in place, for the insertions of their kinds in the pass.
  ///
  /// A render pass removes the items that left before it inserts the new ones, so the views of the rows that a scroll
  /// moves out serve the rows that it moves in where they are, instead of leaving their window and coming back from the
  /// pool. Removing a view from its window and adding it back calls the window callbacks of every view in its subtree,
  /// and makes AppKit display it again, while moving it among its siblings does neither. The views that no insertion
  /// takes leave at the end of the pass, for the pool.
  ///
  /// It's a class that the view keeps in a constant, instead of a structure in a variable, since each call on a
  /// structure in a variable of the view checks at run time that no other access to the variable overlaps it, which
  /// costs more than the call itself in a pass that keeps no view.
  final class InPlaceReuse {

    /// The kept views, by their reuse keys. An emptied array stays with its capacity, instead of being removed, so that
    /// a steady scroll keeps and takes views without allocating.
    private var renderables: [ReuseKey: [Renderable]] = [:]

    /// The number of kept views, which lets a pass that keeps none skip the lookups.
    private var count = 0

    /// Returns whether a reusable renderable that leaves during a render pass can stay in place.
    ///
    /// Only a view stays, since a layer leaves and comes back without callbacks. A view that stays keeps its window, so
    /// it gives up the first responder in it, as leaving the window would.
    ///
    /// - Parameter renderable: The renderable that leaves.
    /// - Returns: Whether the renderable can stay in place.
    static func canKeep(_ renderable: Renderable) -> Bool {
      switch renderable {
      case .view(let view):
        #if canImport(AppKit)
        // AppKit takes the first responder away from a view that leaves its window, while `makeFirstResponder(nil)`
        // only asks it to resign, which it can refuse, so a view with the first responder inside leaves as before
        if let firstResponder = view.window?.firstResponder as? NSView, firstResponder.isDescendant(of: view) {
          return false
        }
        #endif

        #if canImport(UIKit)
        view.endEditing(true)
        #endif

        return true
      case .layer:
        return false
      }
    }

    /// Keeps a view for an insertion of its kind later in the pass.
    ///
    /// - Parameters:
    ///   - renderable: The view, reset for its reuse.
    ///   - key: The view's reuse key.
    func keep(_ renderable: Renderable, key: ReuseKey) {
      renderables[key, default: []].append(renderable)
      count += 1
    }

    /// Takes a kept view of a kind.
    ///
    /// - Parameter key: The reuse key.
    /// - Returns: A kept view, or `nil` if there's none of the kind.
    func take(_ key: ReuseKey) -> Renderable? {
      guard count > 0,
            let index = renderables.index(forKey: key),
            let renderable = renderables.values[index].popLast()
      else {
        return nil
      }
      count -= 1
      return renderable
    }

    /// Removes the kept views, which no insertion took, from their parent, and adds them to a pool.
    ///
    /// - Parameter pool: The pool, or `nil` to release the views. It's an autoclosure, read only when there are views
    ///   to remove, since reading the compose view's pool for a plain argument costs more than the rest of the call in
    ///   a pass that keeps no view.
    func removeAll(addingTo pool: @autoclosure () -> RenderablePoolType?) {
      guard count > 0 else {
        return
      }

      let pool = pool()

      // the index advances by hand, instead of iterating `renderables.indices`, which holds the dictionary's storage,
      // so emptying an array in the loop would copy the whole dictionary
      var index = renderables.startIndex
      while index != renderables.endIndex {
        let key = renderables.keys[index]
        for renderable in renderables.values[index] {
          renderable.removeFromParent()
          pool?.enqueue(renderable, key: key)
        }
        renderables.values[index].removeAll(keepingCapacity: true)
        renderables.formIndex(after: &index)
      }
      count = 0
    }
  }
}
