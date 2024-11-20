//
//  RenderItem.swift
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// A render item that is a view.
public typealias ViewItem<T: View> = RenderItem<T>

/// A render item that is a layer.
public typealias LayerItem<T: CALayer> = RenderItem<T>

/// A render item that is either a view or a layer.
public typealias RenderableItem = RenderItem<Renderable>

// MARK: - RenderItem

/// An item that can provide a renderable with its frame and lifecycle callbacks.
public struct RenderItem<T> {

  /// The unique id of the renderable.
  public var id: ComposeNodeId

  /// The frame of the renderable.
  public var frame: CGRect

  /// The block to create a renderable.
  public let make: (RenderableMakeContext) -> T

  /// The block to be called when the renderable is just made and is about to be inserted into the renderable hierarchy.
  ///
  /// At this point, the renderable is not inserted into the renderable hierarchy yet, and the renderable's frame is not set yet.
  /// The passed in context contains the old frame before the insertion and the new frame that the renderable should be set to
  /// after the insertion.
  ///
  /// This is guaranteed to be the first call for the renderable's lifecycle in the renderable hierarchy.
  public let willInsert: ((T, RenderableInsertContext) -> Void)?

  /// The block to be called when the renderable is just inserted into the renderable hierarchy.
  ///
  /// At the point, the renderable is already inserted into the renderable hierarchy with its transition animation completed.
  /// The passed in context contains the old frame that is set just after the willInsert block is called, and the new
  /// frame that the renderable should be set to after the insertion. However, at this point, the renderable's frame may not be the
  /// same as the new frame, because during the transition animation, the renderable maybe updated for additional changes.
  ///
  /// This is not guaranteed to be called before the `update` block is called.
  public let didInsert: ((T, RenderableInsertContext) -> Void)?

  /// The block to be called when the renderable is about to be updated.
  ///
  /// At this point, the renderable might be not inserted into the renderable hierarchy yet. The renderable's properties, including its
  /// frame, are not updated yet. You can use this block to get the properties of the renderable before the update and use the
  /// information to help renderable content update. For example, to get the old properties for animating the renderable's changes.
  public let willUpdate: ((T, RenderableUpdateContext) -> Void)?

  /// The block to be called when the renderable's frame is just updated and is ready to be updated for additional changes.
  ///
  /// This block is called when a renderable just finishes its insertion (after the transition animation) or when the renderable is
  /// reused because of refresh, scroll, etc.
  ///
  /// In the block, the renderable should be updated to reflect its intended content. For example, if the renderable is for a
  /// `ColorNode`, the renderable should render the specified color.
  ///
  /// Note that it is possible that when a renderable is being inserted into the renderable hierarchy with a transition animation, a
  /// new update, which is triggered by a `refresh()`, is called on the renderable. In this case, an update call with
  /// `RenderableUpdateType.refresh` type will be called before the update call with `RenderableUpdateType.insert` type.
  public let update: (T, RenderableUpdateContext) -> Void

  /// The block to be called when the renderable is about to be removed from the renderable hierarchy.
  ///
  /// At this point, the renderable is still in the renderable hierarchy, but it is about to be removed, before the transition
  /// animation if has one.
  public let willRemove: ((T, RenderableRemoveContext) -> Void)?

  /// The block to be called when the renderable is just removed from the renderable hierarchy.
  ///
  /// At this point, the renderable is already removed from the renderable hierarchy with its transition animation completed.
  ///
  /// Note that it is possible that a removing renderable, during its removal transition animation, is re-inserted into the
  /// renderable hierarchy. In this case, the `didRemove` block won't be called.
  public let didRemove: ((T, RenderableRemoveContext) -> Void)?

  /// The transition of the renderable. The transition is used to animate the renderable's insertion and removal.
  public let transition: RenderableTransition?

  /// The animation timing of the renderable. The animation timing is used to animate the renderable's changes.
  public let animationTiming: AnimationTiming?

  public init(id: ComposeNodeId,
              frame: CGRect,
              make: @escaping (RenderableMakeContext) -> T,
              willInsert: ((T, RenderableInsertContext) -> Void)? = nil,
              didInsert: ((T, RenderableInsertContext) -> Void)? = nil,
              willUpdate: ((T, RenderableUpdateContext) -> Void)? = nil,
              update: @escaping (T, RenderableUpdateContext) -> Void,
              willRemove: ((T, RenderableRemoveContext) -> Void)? = nil,
              didRemove: ((T, RenderableRemoveContext) -> Void)? = nil,
              transition: RenderableTransition? = nil,
              animationTiming: AnimationTiming? = nil)
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
    self.animationTiming = animationTiming
  }

  /// Add an additional will insert block to the renderable item.
  ///
  /// - Parameter additionalWillInsert: The additional will insert block.
  /// - Returns: The renderable item with the additional will insert block.
  public func addWillInsert(_ additionalWillInsert: @escaping (T, RenderableInsertContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: { renderable, context in
        willInsert?(renderable, context)
        additionalWillInsert(renderable, context)
      },
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animationTiming: animationTiming
    )
  }

  /// Add an additional did insert block to the renderable item.
  ///
  /// - Parameter additionalDidInsert: The additional did insert block.
  /// - Returns: The renderable item with the additional did insert block.
  public func addDidInsert(_ additionalDidInsert: @escaping (T, RenderableInsertContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: { renderable, context in
        didInsert?(renderable, context)
        additionalDidInsert(renderable, context)
      },
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animationTiming: animationTiming
    )
  }

  /// Add an additional will update block to the renderable item.
  ///
  /// - Parameter additionalWillUpdate: The additional will update block.
  /// - Returns: The renderable item with the additional will update block.
  public func addWillUpdate(_ additionalWillUpdate: @escaping (T, RenderableUpdateContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: { renderable, context in
        willUpdate?(renderable, context)
        additionalWillUpdate(renderable, context)
      },
      update: update,
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animationTiming: animationTiming
    )
  }

  /// Add an additional update block to the renderable item.
  ///
  /// - Parameter additionalUpdate: The additional update block.
  /// - Returns: The renderable item with the additional update block.
  public func addUpdate(_ additionalUpdate: @escaping (T, RenderableUpdateContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: { renderable, context in
        update(renderable, context)
        additionalUpdate(renderable, context)
      },
      willRemove: willRemove,
      didRemove: didRemove,
      transition: transition,
      animationTiming: animationTiming
    )
  }

  /// Add an additional will remove block to the renderable item.
  ///
  /// - Parameter additionalWillRemove: The additional will remove block.
  /// - Returns: The renderable item with the additional will remove block.
  public func addWillRemove(_ additionalWillRemove: @escaping (T, RenderableRemoveContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: { renderable, context in
        willRemove?(renderable, context)
        additionalWillRemove(renderable, context)
      },
      didRemove: didRemove,
      transition: transition,
      animationTiming: animationTiming
    )
  }

  /// Add an additional did remove block to the renderable item.
  ///
  /// - Parameter additionalDidRemove: The additional did remove block.
  /// - Returns: The renderable item with the additional did remove block.
  public func addDidRemove(_ additionalDidRemove: @escaping (T, RenderableRemoveContext) -> Void) -> Self {
    Self(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: { renderable, context in
        didRemove?(renderable, context)
        additionalDidRemove(renderable, context)
      },
      transition: transition,
      animationTiming: animationTiming
    )
  }

  /// Set a new transition for the renderable item if it is not set.
  ///
  /// If the renderable item already has a transition, this call has no effect.
  ///
  /// - Parameter transition: The new transition.
  /// - Returns: The renderable item with the new transition.
  public func transition(_ transition: RenderableTransition) -> Self {
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
      animationTiming: animationTiming
    )
  }

  /// Set a new animation for the renderable item if it is not set.
  ///
  /// If the renderable item already has an animation, this call has no effect.
  ///
  /// - Parameter animationTiming: The new animation timing.
  /// - Returns: The renderable item with the new animation.
  public func animation(_ animationTiming: AnimationTiming) -> Self {
    guard self.animationTiming == nil else {
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
      animationTiming: animationTiming
    )
  }
}

public extension ViewItem {

  /// Erase the view item to a generic `RenderableItem`.
  ///
  /// - Returns: The erased renderable item.
  func eraseToRenderableItem() -> RenderableItem {
    RenderableItem(
      id: id,
      frame: frame,
      make: { .view(make($0)) },
      willInsert: willInsert.map { willInsert in
        { willInsert($0.view as! T, $1) } // swiftlint:disable:this force_cast
      },
      didInsert: didInsert.map { didInsert in
        { didInsert($0.view as! T, $1) } // swiftlint:disable:this force_cast
      },
      willUpdate: willUpdate.map { willUpdate in
        { willUpdate($0.view as! T, $1) } // swiftlint:disable:this force_cast
      },
      update: {
        update($0.view as! T, $1) // swiftlint:disable:this force_cast
      },
      willRemove: willRemove.map { willRemove in
        { willRemove($0.view as! T, $1) } // swiftlint:disable:this force_cast
      },
      didRemove: didRemove.map { didRemove in
        { didRemove($0.view as! T, $1) } // swiftlint:disable:this force_cast
      },
      transition: transition,
      animationTiming: animationTiming
    )
  }
}

public extension LayerItem {

  /// Erase the layer item to a generic `RenderableItem`.
  ///
  /// - Returns: The erased renderable item.
  func eraseToRenderableItem() -> RenderableItem {
    RenderableItem(
      id: id,
      frame: frame,
      make: { .layer(make($0)) },
      willInsert: willInsert.map { willInsert in
        { willInsert($0.layer as! T, $1) } // swiftlint:disable:this force_cast
      },
      didInsert: didInsert.map { didInsert in
        { didInsert($0.layer as! T, $1) } // swiftlint:disable:this force_cast
      },
      willUpdate: willUpdate.map { willUpdate in
        { willUpdate($0.layer as! T, $1) } // swiftlint:disable:this force_cast
      },
      update: {
        update($0.layer as! T, $1) // swiftlint:disable:this force_cast
      },
      willRemove: willRemove.map { willRemove in
        { willRemove($0.layer as! T, $1) } // swiftlint:disable:this force_cast
      },
      didRemove: didRemove.map { didRemove in
        { didRemove($0.layer as! T, $1) } // swiftlint:disable:this force_cast
      },
      transition: transition,
      animationTiming: animationTiming
    )
  }
}
