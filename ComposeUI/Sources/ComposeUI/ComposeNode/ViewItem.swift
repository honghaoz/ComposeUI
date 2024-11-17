//
//  ViewItem.swift
//  ComposeUI
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// An item that can provide a view with its frame and lifecycle callbacks.
public struct ViewItem<T: View> {

  /// The unique id of the view item.
  var id: ComposeNodeId

  /// The frame of the view.
  var frame: CGRect

  /// The block to create a view.
  let make: (ViewMakeContext) -> T

  /// The block to be called when the view is just made and is about to be inserted into the view hierarchy.
  ///
  /// At this point, the view is not inserted into the view hierarchy yet, and the view's frame is not set yet.
  /// The passed in context contains the old frame before the insertion and the new frame that the view should be set to
  /// after the insertion.
  ///
  /// This is guaranteed to be the first call for the view's lifecycle in the view hierarchy.
  let willInsert: ((T, ViewInsertContext) -> Void)?

  /// The block to be called when the view is just inserted into the view hierarchy.
  ///
  /// At the point, the view is already inserted into the view hierarchy with its transition animation completed.
  /// The passed in context contains the old frame that is set just after the willInsert block is called, and the new
  /// frame that the view should be set to after the insertion. However, at this point, the view's frame may not be the
  /// same as the new frame, because during the transition animation, the view maybe updated for additional changes.
  ///
  /// This is not guaranteed to be called before the `update` block is called.
  let didInsert: ((T, ViewInsertContext) -> Void)?

  /// The block to be called when the view is about to be updated.
  ///
  /// At this point, the view's properties, including its frame, are not updated yet. You can use this block to get the
  /// properties of the view before the update and use the information to help view content update. For example, to get
  /// the old properties for animating the view's changes.
  let willUpdate: ((T, ViewUpdateContext) -> Void)?

  /// The block to be called when the view's frame is just updated and is ready to be updated for additional changes.
  ///
  /// This block is called when a view just finishes its insertion (after the transition animation) or when the view is
  /// reused because of refresh, scroll, etc.
  ///
  /// In the block, the view should be updated to reflect its intended content. For example, if the view is for a
  /// `ColorNode`, the view should render the specified color.
  ///
  /// Note that it is possible that when a view is being inserted into the view hierarchy with a transition animation, a
  /// new update, which is triggered by a `refresh()`, is called on the view. In this case, an update call with
  /// `ViewUpdateType.refresh` type will be called before the update call with `ViewUpdateType.insert` type.
  let update: (T, ViewUpdateContext) -> Void

  /// The block to be called when the view is about to be removed from the view hierarchy.
  ///
  /// At this point, the view is still in the view hierarchy, but it is about to be removed, before the transition
  /// animation if has one.
  let willRemove: ((T, ViewRemoveContext) -> Void)?

  /// The block to be called when the view is just removed from the view hierarchy.
  ///
  /// At this point, the view is already removed from the view hierarchy with its transition animation completed.
  ///
  /// Note that it is possible that a removing view, during its removal transition animation, is re-inserted into the
  /// view hierarchy. In this case, the `didRemove` block won't be called.
  let didRemove: ((T, ViewRemoveContext) -> Void)?

  /// The transition of the view. The transition is used to animate the view's insertion and removal.
  let transition: ViewTransition?

  /// The animation of the view. The animation is used to animate the view's changes.
  let animation: ViewAnimation?

  public init(id: ComposeNodeId,
              frame: CGRect,
              make: @escaping (ViewMakeContext) -> T = { _ in T() },
              willInsert: ((T, ViewInsertContext) -> Void)? = nil,
              didInsert: ((T, ViewInsertContext) -> Void)? = nil,
              willUpdate: ((T, ViewUpdateContext) -> Void)? = nil,
              update: @escaping (T, ViewUpdateContext) -> Void,
              willRemove: ((T, ViewRemoveContext) -> Void)? = nil,
              didRemove: ((T, ViewRemoveContext) -> Void)? = nil,
              transition: ViewTransition? = nil,
              animation: ViewAnimation? = nil)
  {
    self.id = id
    self.frame = frame
    self.make = make
    self.willInsert = willInsert
    self.didInsert = didInsert
    self.willUpdate = willUpdate
    self.update = update
    self.willRemove = willRemove
    self.didRemove = didRemove
    self.transition = transition
    self.animation = animation
  }

  /// Add an additional will insert block to the view item.
  ///
  /// - Parameter additionalWillInsert: The additional will insert block.
  /// - Returns: The view item with the additional will insert block.
  public func addWillInsert(_ additionalWillInsert: @escaping (T, ViewInsertContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: { view, context in
        willInsert?(view, context)
        additionalWillInsert(view, context)
      },
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animation: animation
    )
  }

  /// Add an additional did insert block to the view item.
  ///
  /// - Parameter additionalDidInsert: The additional did insert block.
  /// - Returns: The view item with the additional did insert block.
  public func addDidInsert(_ additionalDidInsert: @escaping (T, ViewInsertContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: { view, context in
        didInsert?(view, context)
        additionalDidInsert(view, context)
      },
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animation: animation
    )
  }

  /// Add an additional will update block to the view item.
  ///
  /// - Parameter additionalWillUpdate: The additional will update block.
  /// - Returns: The view item with the additional will update block.
  public func addWillUpdate(_ additionalWillUpdate: @escaping (T, ViewUpdateContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: { view, context in
        willUpdate?(view, context)
        additionalWillUpdate(view, context)
      },
      update: update,
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animation: animation
    )
  }

  /// Add an additional update block to the view item.
  ///
  /// - Parameter additionalUpdate: The additional update block.
  /// - Returns: The view item with the additional update block.
  public func addUpdate(_ additionalUpdate: @escaping (T, ViewUpdateContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: { view, context in
        update(view, context)
        additionalUpdate(view, context)
      },
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animation: animation
    )
  }

  /// Add an additional will remove block to the view item.
  ///
  /// - Parameter additionalWillRemove: The additional will remove block.
  /// - Returns: The view item with the additional will remove block.
  public func addWillRemove(_ additionalWillRemove: @escaping (T, ViewRemoveContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: { view, context in
        willRemove?(view, context)
        additionalWillRemove(view, context)
      },
      didRemove: didRemove,
      transition: transition,
      animation: animation
    )
  }

  /// Add an additional did remove block to the view item.
  ///
  /// - Parameter additionalDidRemove: The additional did remove block.
  /// - Returns: The view item with the additional did remove block.
  public func addDidRemove(_ additionalDidRemove: @escaping (T, ViewRemoveContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: { view, context in
        didRemove?(view, context)
        additionalDidRemove(view, context)
      },
      transition: transition,
      animation: animation
    )
  }

  /// Set a new transition for the view item if it is not set.
  ///
  /// If the view item already has a transition, this call has no effect.
  ///
  /// - Parameter transition: The new transition.
  /// - Returns: The view item with the new transition.
  public func transition(_ transition: ViewTransition) -> Self {
    guard self.transition == nil else {
      return self
    }

    return Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animation: animation
    )
  }

  /// Set a new animation for the view item if it is not set.
  ///
  /// If the view item already has an animation, this call has no effect.
  ///
  /// - Parameter animation: The new animation.
  /// - Returns: The view item with the new animation.
  public func animation(_ animation: ViewAnimation) -> Self {
    guard self.animation == nil else {
      return self
    }

    return Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animation: animation
    )
  }

  /// Erase the view type to a generic `View` item.
  ///
  /// - Returns: The view item with the generic `View` type.
  func eraseToViewItem() -> ViewItem<View> {
    if let viewItem = self as? ViewItem<View> {
      return viewItem
    }

    return ViewItem<View>(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert.map { willInsert in
        { willInsert($0 as! T, $1) } // swiftlint:disable:this force_cast
      },
      didInsert: didInsert.map { didInsert in
        { didInsert($0 as! T, $1) } // swiftlint:disable:this force_cast
      },
      willUpdate: willUpdate.map { willUpdate in
        { willUpdate($0 as! T, $1) } // swiftlint:disable:this force_cast
      },
      update: { update($0 as! T, $1) }, // swiftlint:disable:this force_cast
      willRemove: willRemove.map { willRemove in
        { willRemove($0 as! T, $1) } // swiftlint:disable:this force_cast
      },
      didRemove: didRemove.map { didRemove in
        { didRemove($0 as! T, $1) } // swiftlint:disable:this force_cast
      },
      transition: transition,
      animation: animation
    )
  }
}
