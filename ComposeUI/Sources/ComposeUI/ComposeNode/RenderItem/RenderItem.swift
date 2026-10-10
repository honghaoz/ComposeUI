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

// MARK: - RenderableUpdateKey

/// The renderable property that a built-in modifier's update block sets.
///
/// Of a render item's update blocks with one key, only the last one runs, at its own position. Stacked modifiers of
/// one property, for example `.opacity(0.3).opacity(1)`, then apply only the outermost value, since applying each value
/// in turn would animate the layer through the overridden values.
///
/// - Note: A raw value is the key's bit index in a `UInt64`, so there can be at most 64 keys.
enum RenderableUpdateKey: UInt64 {
  case backgroundColor
  case opacity
  case border
  case cornerRadius
  case masksToBounds
  case shadow
  case interactive
  case rasterize
}

// MARK: - RenderItem

/// An item that can provide a renderable with its frame and lifecycle callbacks.
public struct RenderItem<T> {

  /// The unique id of the item.
  public var id: ComposeNodeId

  /// The frame of the renderable.
  public var frame: CGRect

  /// The renderable's behavior: the lifecycle callbacks plus the reuse / transition / animation configuration.
  ///
  /// This is boxed in a reference type so that copying a `RenderItem`, which the render walk does at every container
  /// level, is a single retain instead of copying ~10 escaping closures, and so the value type stays small (cheaper to
  /// store in, and tear down, the per-pass render dictionaries). `id` and `frame` stay inline because they are mutated
  /// per render pass.
  private let storage: Storage

  /// The block to create a renderable.
  public var make: (RenderableMakeContext) -> T {
    let storage = storage
    switch storage.source {
    case .make(let make):
      return make
    case .typedItem:
      return { storage.makeRenderable($0) }
    }
  }

  /// The block to be called when the renderable is just made and is about to be inserted into the renderable hierarchy.
  ///
  /// At this point, the renderable is not inserted into the renderable hierarchy yet, and the renderable's frame is not set yet.
  /// The passed in context contains the old frame before the insertion and the new frame that the renderable should be set to
  /// after the insertion.
  ///
  /// The block must not change the renderable's transform, the frame is applied right after it and requires an identity
  /// transform, see `Renderable`. Set a transform in `update` instead.
  ///
  /// This is guaranteed to be the first call for the renderable's lifecycle in the renderable hierarchy.
  public var willInsert: ((T, RenderableInsertContext) -> Void)? {
    let storage = storage
    guard storage.typedItem(with: .willInsert) != nil else {
      return storage.willInsert
    }
    return { storage.performWillInsert($0, $1) }
  }

  /// The block to be called when the renderable is just inserted into the renderable hierarchy.
  ///
  /// At the point, the renderable is already inserted into the renderable hierarchy with its transition animation completed.
  /// The passed in context contains the old frame that is set just after the willInsert block is called, and the new
  /// frame that the renderable should be set to after the insertion. However, at this point, the renderable's frame may not be the
  /// same as the new frame, because during the transition animation, the renderable maybe updated for additional changes.
  ///
  /// This is not guaranteed to be called before the `update` block is called.
  public var didInsert: ((T, RenderableInsertContext) -> Void)? {
    let storage = storage
    guard storage.typedItem(with: .didInsert) != nil else {
      return storage.didInsert
    }
    return { storage.performDidInsert($0, $1) }
  }

  /// The block to be called when the renderable is about to be updated.
  ///
  /// At this point, the renderable might be not inserted into the renderable hierarchy yet. The renderable's properties, including its
  /// frame, are not updated yet. You can use this block to get the properties of the renderable before the update and use the
  /// information to help renderable content update. For example, to get the old properties for animating the renderable's changes.
  ///
  /// The block must not change the renderable's transform, the frame is applied right after it and requires an identity
  /// transform, see `Renderable`. Set a transform in `update` instead.
  public var willUpdate: ((T, RenderableUpdateContext) -> Void)? {
    let storage = storage
    guard storage.typedItem(with: .willUpdate) != nil else {
      return storage.willUpdate
    }
    return { storage.performWillUpdate($0, $1) }
  }

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
  public var update: (T, RenderableUpdateContext) -> Void {
    let storage = storage
    guard !storage.additionalUpdates.isEmpty else {
      return storage.update
    }
    return { renderable, context in
      storage.performUpdate(renderable, context)
    }
  }

  /// The block to be called when the renderable is about to be removed from the renderable hierarchy.
  ///
  /// At this point, the renderable is still in the renderable hierarchy, but it is about to be removed, before the transition
  /// animation if has one.
  public var willRemove: ((T, RenderableRemoveContext) -> Void)? {
    let storage = storage
    guard storage.typedItem(with: .willRemove) != nil else {
      return storage.willRemove
    }
    return { storage.performWillRemove($0, $1) }
  }

  /// The block to be called when the renderable is just removed from the renderable hierarchy.
  ///
  /// At this point, the renderable is already removed from the renderable hierarchy with its transition animation completed.
  ///
  /// Note that it is possible that a removing renderable, during its removal transition animation, is re-inserted into the
  /// renderable hierarchy. In this case, the `didRemove` block won't be called.
  public var didRemove: ((T, RenderableRemoveContext) -> Void)? {
    let storage = storage
    guard storage.typedItem(with: .didRemove) != nil else {
      return storage.didRemove
    }
    return { storage.performDidRemove($0, $1) }
  }

  /// An optional reuse identifier that opts the renderable into the recycle pool.
  ///
  /// When set, a renderable that is removed from the renderable hierarchy is added to a pool (keyed by this identifier
  /// and the renderable's concrete type) instead of being deallocated, and is handed back when a new item with the same
  /// reuse identifier and type is inserted, avoiding a `make` call.
  ///
  /// To ensure a reused renderable is in the same state a freshly made one would have, use the `resetForReuse` block to
  /// reset the renderable's modified properties.
  var reuseId: ReuseId? { storage.reuseId }

  /// The concrete renderable type generated by `ObjectIdentifier(T.self)`.
  var renderableType: ObjectIdentifier? { storage.renderableType }

  /// The block to be called when the renderable is about to be added to the reuse pool, to reset any modified state so
  /// the reused renderable is clean (freshly-made-equivalent) for its next use.
  public var resetForReuse: ((T) -> Void)? {
    let storage = storage
    guard storage.typedItem(with: .resetForReuse) != nil else {
      return storage.resetForReuse
    }
    return { storage.performResetForReuse($0) }
  }

  /// The transition of the renderable. The transition is used to animate the renderable's insertion and removal.
  public var transition: RenderableTransition? { storage.transition }

  /// The animation timing of the renderable. The animation timing is used to animate the renderable's changes.
  public var animationTiming: AnimationTiming? { storage.animationTiming }

  /// The z-index of the renderable, controlling its stacking band. See `ComposeNode.zIndex(_:)`.
  ///
  /// The render pass computes the renderable layer's actual `zPosition` from this value (defaulting to 0) plus a
  /// small items-order fraction, so that items stack in the items order within the same z-index band.
  public var zIndex: CGFloat? { storage.zIndex }

  /// Makes a renderable with the `make` block.
  ///
  /// The render pass calls this and the `perform` methods instead of reading the blocks, since reading a block of an
  /// erased item builds a new block, see `eraseToRenderableItem()`.
  func makeRenderable(_ context: RenderableMakeContext) -> T {
    storage.makeRenderable(context)
  }

  /// Runs the `willInsert` block, if any.
  func performWillInsert(_ renderable: T, _ context: RenderableInsertContext) {
    storage.performWillInsert(renderable, context)
  }

  /// Runs the `didInsert` block, if any.
  func performDidInsert(_ renderable: T, _ context: RenderableInsertContext) {
    storage.performDidInsert(renderable, context)
  }

  /// Runs the `willUpdate` block, if any.
  func performWillUpdate(_ renderable: T, _ context: RenderableUpdateContext) {
    storage.performWillUpdate(renderable, context)
  }

  /// Runs `update`, then the additional update blocks in the order they were added.
  ///
  /// The render pass calls this instead of reading `update`, which builds a new block for an item with additional
  /// update blocks.
  func performUpdate(_ renderable: T, _ context: RenderableUpdateContext) {
    storage.performUpdate(renderable, context)
  }

  /// Runs the `willRemove` block, if any.
  func performWillRemove(_ renderable: T, _ context: RenderableRemoveContext) {
    storage.performWillRemove(renderable, context)
  }

  /// Runs the `didRemove` block, if any.
  func performDidRemove(_ renderable: T, _ context: RenderableRemoveContext) {
    storage.performDidRemove(renderable, context)
  }

  /// Runs the `resetForReuse` block, if any.
  func performResetForReuse(_ renderable: T) {
    storage.performResetForReuse(renderable)
  }

  /// An update block added to a render item, optionally keyed by the renderable property it sets.
  struct AdditionalUpdate {

    /// The update block.
    ///
    /// Stored before `key`, so that the key's byte packs after `Block`'s tag byte. The other way around, padding
    /// makes each node of `AdditionalUpdates` 16 bytes larger.
    private let block: Block

    /// The renderable property the block sets, see `RenderableUpdateKey`. `nil` for a block that is never replaced.
    let key: RenderableUpdateKey?

    fileprivate init(block: Block, key: RenderableUpdateKey?) {
      self.block = block
      self.key = key
    }

    /// Runs the block.
    func perform(_ renderable: T, _ context: RenderableUpdateContext) {
      switch block {
      case .generic(let block):
        block(renderable, context)
      case .renderable(let block):
        // only `init(key:block:)` makes a `renderable` block, and it requires `T` to be `Renderable`, so the cast does
        // nothing
        block(renderable as! Renderable, context) // swiftlint:disable:this force_cast
      }
    }

    /// An update block, stored with the renderable type it takes.
    ///
    /// A closure that takes a `Renderable` is stored as it is instead of as a `(T, RenderableUpdateContext) -> Void`: a
    /// closure typed with the generic `T` takes the renderable indirectly, so converting an existing closure to it
    /// allocates a reabstraction thunk, for example for each `onUpdate` modifier.
    fileprivate enum Block {

      /// A block that takes the item's renderable type, see `addUpdate(_:)`.
      case generic((T, RenderableUpdateContext) -> Void)

      /// A block that takes a `Renderable`, which only a `RenderableItem` has, see `init(key:block:)`.
      case renderable((Renderable, RenderableUpdateContext) -> Void)
    }
  }

  /// The update blocks added to a render item, in the order they run.
  ///
  /// A keyed block overrides the earlier blocks of its key: they are skipped when the blocks run, see `RenderableUpdateKey`.
  ///
  /// Nodes are rebuilt on every refresh and items on every render pass, so the blocks form a linked list that adding a
  /// block extends without copying the others, with a single block stored inline. An array would copy its blocks each
  /// time a coalescing modifier adds one, since the inner modifier still holds them.
  enum AdditionalUpdates {

    case none
    case one(AdditionalUpdate)
    indirect case more(AdditionalUpdate, previous: AdditionalUpdates)

    /// Whether the list has no blocks.
    var isEmpty: Bool {
      switch self {
      case .none:
        return true
      case .one,
           .more:
        return false
      }
    }

    /// Returns the list with a block added to run last.
    func adding(_ update: AdditionalUpdate) -> AdditionalUpdates {
      switch self {
      case .none:
        return .one(update)
      case .one,
           .more:
        return .more(update, previous: self)
      }
    }

    /// Returns the list with another list's blocks added to run after its own, in order.
    func adding(contentsOf other: AdditionalUpdates) -> AdditionalUpdates {
      guard !isEmpty else {
        return other
      }
      switch other {
      case .none:
        return self
      case .one(let update):
        return adding(update)
      case .more(let update, let previous):
        return adding(contentsOf: previous).adding(update)
      }
    }

    /// Calls the body with each block that isn't overridden, in order.
    func forEach(_ body: (AdditionalUpdate) -> Void) {
      forEach(skipping: KeySet(), body)
    }

    private func forEach(skipping laterKeys: KeySet, _ body: (AdditionalUpdate) -> Void) {
      switch self {
      case .none:
        break
      case .one(let update):
        if !laterKeys.contains(update.key) {
          body(update)
        }
      case .more(let update, let previous):
        previous.forEach(skipping: laterKeys.inserting(update.key), body)
        if !laterKeys.contains(update.key) {
          body(update)
        }
      }
    }

    /// The keys of the blocks that run later, as bits, so that running the blocks allocates nothing.
    private struct KeySet {

      private var bits: UInt64 = 0

      func contains(_ key: RenderableUpdateKey?) -> Bool {
        guard let key else {
          return false
        }
        return bits & (1 << key.rawValue) != 0
      }

      func inserting(_ key: RenderableUpdateKey?) -> KeySet {
        guard let key else {
          return self
        }
        var keySet = self
        keySet.bits |= 1 << key.rawValue
        return keySet
      }
    }
  }

  /// Where an item's renderable and its lifecycle blocks come from.
  fileprivate enum Source {

    /// The item's own `make` block, with the item's own lifecycle blocks.
    case make((RenderableMakeContext) -> T)

    /// The storage of the view or layer item that the item was erased from, which makes the renderable and runs its
    /// lifecycle blocks, of the kinds in `blocks`, see `eraseToRenderableItem()`. Only a `RenderableItem` has one.
    case typedItem(any TypedItemStorage, blocks: TypedItemBlocks)
  }

  /// The boxed behavior backing a `RenderItem`. See `storage`.
  ///
  /// Holds everything except `id` and `frame`. Because all fields are immutable, the box can be shared freely across
  /// the copies a render pass makes (containers copy child items to re-position them), so each copy is one retain.
  fileprivate final class Storage {

    /// Where the renderable and the lifecycle blocks come from.
    ///
    /// For an erased item, the typed item's lifecycle block of each kind runs before the item's own, which are then the
    /// blocks added after erasing, see `Source.typedItem`.
    let source: Source

    let willInsert: ((T, RenderableInsertContext) -> Void)?
    let didInsert: ((T, RenderableInsertContext) -> Void)?
    let willUpdate: ((T, RenderableUpdateContext) -> Void)?
    let update: (T, RenderableUpdateContext) -> Void

    /// The update blocks added after `update`, see `addUpdate(_:)` and `addUpdates(_:)`.
    let additionalUpdates: AdditionalUpdates

    let willRemove: ((T, RenderableRemoveContext) -> Void)?
    let didRemove: ((T, RenderableRemoveContext) -> Void)?
    let reuseId: ReuseId?
    let renderableType: ObjectIdentifier?
    let resetForReuse: ((T) -> Void)?
    let transition: RenderableTransition?
    let animationTiming: AnimationTiming?
    let zIndex: CGFloat?

    init(source: Source,
         willInsert: ((T, RenderableInsertContext) -> Void)?,
         didInsert: ((T, RenderableInsertContext) -> Void)?,
         willUpdate: ((T, RenderableUpdateContext) -> Void)?,
         update: @escaping (T, RenderableUpdateContext) -> Void,
         additionalUpdates: AdditionalUpdates,
         willRemove: ((T, RenderableRemoveContext) -> Void)?,
         didRemove: ((T, RenderableRemoveContext) -> Void)?,
         reuseId: ReuseId?,
         renderableType: ObjectIdentifier?,
         resetForReuse: ((T) -> Void)?,
         transition: RenderableTransition?,
         animationTiming: AnimationTiming?,
         zIndex: CGFloat?)
    {
      self.source = source
      self.willInsert = willInsert
      self.didInsert = didInsert
      self.willUpdate = willUpdate
      self.update = update
      self.additionalUpdates = additionalUpdates
      self.willRemove = willRemove
      self.didRemove = didRemove
      self.reuseId = reuseId
      self.renderableType = renderableType
      self.resetForReuse = resetForReuse
      self.transition = transition
      self.animationTiming = animationTiming
      self.zIndex = zIndex
    }

    /// The storage of the typed item that the item was erased from, if it has a lifecycle block of the kind.
    func typedItem(with block: TypedItemBlocks) -> (any TypedItemStorage)? {
      switch source {
      case .make:
        return nil
      case .typedItem(let typedItem, let blocks):
        return blocks.contains(block) ? typedItem : nil
      }
    }

    func makeRenderable(_ context: RenderableMakeContext) -> T {
      switch source {
      case .make(let make):
        return make(context)
      case .typedItem(let typedItem, _):
        return Self.fromRenderable(typedItem.makeErased(context))
      }
    }

    func performWillInsert(_ renderable: T, _ context: RenderableInsertContext) {
      typedItem(with: .willInsert)?.performWillInsert(erased: Self.toRenderable(renderable), context)
      willInsert?(renderable, context)
    }

    func performDidInsert(_ renderable: T, _ context: RenderableInsertContext) {
      typedItem(with: .didInsert)?.performDidInsert(erased: Self.toRenderable(renderable), context)
      didInsert?(renderable, context)
    }

    func performWillUpdate(_ renderable: T, _ context: RenderableUpdateContext) {
      typedItem(with: .willUpdate)?.performWillUpdate(erased: Self.toRenderable(renderable), context)
      willUpdate?(renderable, context)
    }

    func performUpdate(_ renderable: T, _ context: RenderableUpdateContext) {
      update(renderable, context)
      additionalUpdates.forEach { $0.perform(renderable, context) }
    }

    func performWillRemove(_ renderable: T, _ context: RenderableRemoveContext) {
      typedItem(with: .willRemove)?.performWillRemove(erased: Self.toRenderable(renderable), context)
      willRemove?(renderable, context)
    }

    func performDidRemove(_ renderable: T, _ context: RenderableRemoveContext) {
      typedItem(with: .didRemove)?.performDidRemove(erased: Self.toRenderable(renderable), context)
      didRemove?(renderable, context)
    }

    func performResetForReuse(_ renderable: T) {
      typedItem(with: .resetForReuse)?.performResetForReuse(erased: Self.toRenderable(renderable))
      resetForReuse?(renderable)
    }

    // Only a `RenderableItem` has a typed item, see `Source.typedItem`, so where the methods above convert between `T`
    // and `Renderable`, they're the same type and the casts do nothing.

    private static func toRenderable(_ renderable: T) -> Renderable {
      renderable as! Renderable // swiftlint:disable:this force_cast
    }

    private static func fromRenderable(_ renderable: Renderable) -> T {
      renderable as! T // swiftlint:disable:this force_cast
    }
  }

  public init(id: ComposeNodeId,
              frame: CGRect,
              make: @escaping (RenderableMakeContext) -> T,
              willInsert: ((T, RenderableInsertContext) -> Void)? = nil,
              didInsert: ((T, RenderableInsertContext) -> Void)? = nil,
              willUpdate: ((T, RenderableUpdateContext) -> Void)? = nil,
              update: @escaping (T, RenderableUpdateContext) -> Void,
              willRemove: ((T, RenderableRemoveContext) -> Void)? = nil,
              didRemove: ((T, RenderableRemoveContext) -> Void)? = nil,
              reuseId: String? = nil,
              resetForReuse: ((T) -> Void)? = nil,
              transition: RenderableTransition? = nil,
              animationTiming: AnimationTiming? = nil,
              zIndex: CGFloat? = nil)
  {
    self.id = id
    self.frame = frame
    self.storage = Storage(
      source: .make(make),
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      additionalUpdates: .none,
      willRemove: willRemove,
      didRemove: didRemove,
      reuseId: reuseId.map { ReuseId(namespace: .user, id: $0) }, // external callers can only set a user-provided identifier
      renderableType: ObjectIdentifier(T.self),
      resetForReuse: resetForReuse,
      transition: transition,
      animationTiming: animationTiming,
      zIndex: zIndex
    )
  }

  /// Internal initializer for creating a renderable item with a specified renderable type and reuse identifier.
  /// External callers should never set the renderable type manually.
  init(id: ComposeNodeId,
       frame: CGRect,
       make: @escaping (RenderableMakeContext) -> T,
       willInsert: ((T, RenderableInsertContext) -> Void)? = nil,
       didInsert: ((T, RenderableInsertContext) -> Void)? = nil,
       willUpdate: ((T, RenderableUpdateContext) -> Void)? = nil,
       update: @escaping (T, RenderableUpdateContext) -> Void,
       additionalUpdates: AdditionalUpdates = .none,
       willRemove: ((T, RenderableRemoveContext) -> Void)? = nil,
       didRemove: ((T, RenderableRemoveContext) -> Void)? = nil,
       reuseId: ReuseId? = nil,
       renderableType: ObjectIdentifier? = nil,
       resetForReuse: ((T) -> Void)? = nil,
       transition: RenderableTransition? = nil,
       animationTiming: AnimationTiming? = nil,
       zIndex: CGFloat? = nil)
  {
    self.id = id
    self.frame = frame
    self.storage = Storage(
      source: .make(make),
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      additionalUpdates: additionalUpdates,
      willRemove: willRemove,
      didRemove: didRemove,
      reuseId: reuseId,
      renderableType: renderableType,
      resetForReuse: resetForReuse,
      transition: transition,
      animationTiming: animationTiming,
      zIndex: zIndex
    )
  }

  /// Add an additional will insert block to the renderable item.
  ///
  /// - Parameter additionalWillInsert: The additional will insert block.
  /// - Returns: The renderable item with the additional will insert block.
  public func addWillInsert(_ additionalWillInsert: @escaping (T, RenderableInsertContext) -> Void) -> Self {
    let willInsert = storage.willInsert
    return with(willInsert: { renderable, context in
      willInsert?(renderable, context)
      additionalWillInsert(renderable, context)
    })
  }

  /// Add an additional did insert block to the renderable item.
  ///
  /// - Parameter additionalDidInsert: The additional did insert block.
  /// - Returns: The renderable item with the additional did insert block.
  public func addDidInsert(_ additionalDidInsert: @escaping (T, RenderableInsertContext) -> Void) -> Self {
    let didInsert = storage.didInsert
    return with(didInsert: { renderable, context in
      didInsert?(renderable, context)
      additionalDidInsert(renderable, context)
    })
  }

  /// Add an additional will update block to the renderable item.
  ///
  /// - Parameter additionalWillUpdate: The additional will update block.
  /// - Returns: The renderable item with the additional will update block.
  public func addWillUpdate(_ additionalWillUpdate: @escaping (T, RenderableUpdateContext) -> Void) -> Self {
    let willUpdate = storage.willUpdate
    return with(willUpdate: { renderable, context in
      willUpdate?(renderable, context)
      additionalWillUpdate(renderable, context)
    })
  }

  /// Add an additional update block to the renderable item.
  ///
  /// - Parameter additionalUpdate: The additional update block.
  /// - Returns: The renderable item with the additional update block.
  public func addUpdate(_ additionalUpdate: @escaping (T, RenderableUpdateContext) -> Void) -> Self {
    with(additionalUpdates: storage.additionalUpdates.adding(AdditionalUpdate(block: .generic(additionalUpdate), key: nil)))
  }

  /// Add additional update blocks to the renderable item, in order.
  ///
  /// A keyed block overrides the item's earlier blocks of its key, see `RenderableUpdateKey`.
  ///
  /// - Parameter newUpdates: The additional update blocks.
  /// - Returns: The renderable item with the additional update blocks.
  func addUpdates(_ newUpdates: AdditionalUpdates) -> Self {
    with(additionalUpdates: storage.additionalUpdates.adding(contentsOf: newUpdates))
  }

  /// Add an additional will remove block to the renderable item.
  ///
  /// - Parameter additionalWillRemove: The additional will remove block.
  /// - Returns: The renderable item with the additional will remove block.
  public func addWillRemove(_ additionalWillRemove: @escaping (T, RenderableRemoveContext) -> Void) -> Self {
    let willRemove = storage.willRemove
    return with(willRemove: { renderable, context in
      willRemove?(renderable, context)
      additionalWillRemove(renderable, context)
    })
  }

  /// Add an additional did remove block to the renderable item.
  ///
  /// - Parameter additionalDidRemove: The additional did remove block.
  /// - Returns: The renderable item with the additional did remove block.
  public func addDidRemove(_ additionalDidRemove: @escaping (T, RenderableRemoveContext) -> Void) -> Self {
    let didRemove = storage.didRemove
    return with(didRemove: { renderable, context in
      didRemove?(renderable, context)
      additionalDidRemove(renderable, context)
    })
  }

  /// Set a new reuse identifier for the renderable item if it is not set.
  ///
  /// If the renderable item already has a reuse identifier, this call has no effect.
  ///
  /// - Parameter reuseId: The new reuse identifier.
  /// - Returns: The renderable item with the new reuse identifier.
  public func reuseId(_ reuseId: String) -> Self {
    if self.reuseId?.namespace == .user {
      // an inner reuseId(_:) (closer to the leaf) already set a user identifier, so it wins.
      return self
    } else {
      // fills an empty identifier or overrides a framework-internal one, so a user-provided id always takes precedence.
      return with(reuseId: ReuseId(namespace: .user, id: reuseId))
    }
  }

  /// Set a new reuse identifier for the renderable item if it is not set.
  ///
  /// If the renderable item already has a reuse identifier, this call has no effect.
  ///
  /// - Parameter reuseId: The new reuse identifier.
  /// - Returns: The renderable item with the new reuse identifier.
  func reuseId(_ reuseId: ReuseId) -> Self {
    guard self.reuseId == nil else {
      return self
    }

    return with(reuseId: reuseId)
  }

  /// Add an additional reset-for-reuse block to the renderable item.
  ///
  /// - Parameter additionalResetForReuse: The additional reset-for-reuse block.
  /// - Returns: The renderable item with the additional reset-for-reuse block.
  public func addResetForReuse(_ additionalResetForReuse: @escaping (T) -> Void) -> Self {
    let resetForReuse = storage.resetForReuse
    return with(resetForReuse: { renderable in
      resetForReuse?(renderable)
      additionalResetForReuse(renderable)
    })
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

    return with(transition: transition)
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

    return with(animationTiming: animationTiming)
  }

  /// Set a new z-index for the renderable item.
  ///
  /// Unlike `transition(_:)` and `animation(_:)`, this overrides any existing z-index, so that the outermost
  /// `ComposeNode.zIndex(_:)` modifier wins.
  ///
  /// - Parameter zIndex: The new z-index.
  /// - Returns: The renderable item with the new z-index.
  public func zIndex(_ zIndex: CGFloat) -> Self {
    with(zIndex: zIndex)
  }

  /// Makes an item with a storage.
  private init(id: ComposeNodeId, frame: CGRect, storage: Storage) {
    self.id = id
    self.frame = frame
    self.storage = storage
  }

  /// Returns the item with the given blocks and values in place of its own, keeping its other blocks and values, and
  /// its source.
  ///
  /// A `nil` keeps the item's own, since no builder removes a block or a value.
  private func with(willInsert newWillInsert: ((T, RenderableInsertContext) -> Void)? = nil,
                    didInsert newDidInsert: ((T, RenderableInsertContext) -> Void)? = nil,
                    willUpdate newWillUpdate: ((T, RenderableUpdateContext) -> Void)? = nil,
                    additionalUpdates: AdditionalUpdates? = nil,
                    willRemove newWillRemove: ((T, RenderableRemoveContext) -> Void)? = nil,
                    didRemove newDidRemove: ((T, RenderableRemoveContext) -> Void)? = nil,
                    reuseId: ReuseId? = nil,
                    resetForReuse newResetForReuse: ((T) -> Void)? = nil,
                    transition: RenderableTransition? = nil,
                    animationTiming: AnimationTiming? = nil,
                    zIndex: CGFloat? = nil) -> Self
  {
    // the blocks are picked with `if let` instead of `??`, since passing a block through the generic `??` converts it to
    // the generic representation and back, which allocates a reabstraction thunk each way
    var willInsert = storage.willInsert
    if let newWillInsert {
      willInsert = newWillInsert
    }
    var didInsert = storage.didInsert
    if let newDidInsert {
      didInsert = newDidInsert
    }
    var willUpdate = storage.willUpdate
    if let newWillUpdate {
      willUpdate = newWillUpdate
    }
    var willRemove = storage.willRemove
    if let newWillRemove {
      willRemove = newWillRemove
    }
    var didRemove = storage.didRemove
    if let newDidRemove {
      didRemove = newDidRemove
    }
    var resetForReuse = storage.resetForReuse
    if let newResetForReuse {
      resetForReuse = newResetForReuse
    }

    return Self(
      id: id,
      frame: frame,
      storage: Storage(
        source: storage.source,
        willInsert: willInsert,
        didInsert: didInsert,
        willUpdate: willUpdate,
        update: storage.update,
        additionalUpdates: additionalUpdates ?? storage.additionalUpdates,
        willRemove: willRemove,
        didRemove: didRemove,
        reuseId: reuseId ?? storage.reuseId,
        renderableType: storage.renderableType,
        resetForReuse: resetForReuse,
        transition: transition ?? storage.transition,
        animationTiming: animationTiming ?? storage.animationTiming,
        zIndex: zIndex ?? storage.zIndex
      )
    )
  }
}

extension RenderItem.AdditionalUpdate where T == Renderable {

  /// Makes a `RenderableItem`'s update block that takes a `Renderable`, which is stored as it is, see `Block`.
  ///
  /// - Parameters:
  ///   - key: The renderable property the block sets, see `RenderableUpdateKey`. `nil` for a block that is never replaced.
  ///   - block: The update block.
  init(key: RenderableUpdateKey?, block: @escaping (Renderable, RenderableUpdateContext) -> Void) {
    self.init(block: .renderable(block), key: key)
  }
}

extension RenderItem where T == Renderable {

  /// Returns the item with a modifier's blocks and values added, as the builders add them one at a time, see
  /// `addWillInsert(_:)` and the others, in one copy of the item's storage instead of one for each.
  ///
  /// The blocks take a `Renderable`, so a modifier passes its blocks as they are, instead of converting each to a block
  /// that takes the item's generic renderable type, which allocates a reabstraction thunk.
  ///
  /// - Parameters:
  ///   - willInsert: The block to run after the item's `willInsert` block.
  ///   - didInsert: The block to run after the item's `didInsert` block.
  ///   - willUpdate: The block to run after the item's `willUpdate` block.
  ///   - updates: The update blocks to add, see `addUpdates(_:)`.
  ///   - willRemove: The block to run after the item's `willRemove` block.
  ///   - didRemove: The block to run after the item's `didRemove` block.
  ///   - reuseId: The reuse identifier to set, unless the item has a reuse identifier that isn't the framework's, see
  ///     `reuseId(_:)`.
  ///   - resetForReuse: The block to run after the item's `resetForReuse` block.
  ///   - transition: The transition to set, unless the item has one.
  ///   - animationTiming: The animation to set, unless the item has one.
  ///   - zIndex: The z-index to set in place of the item's.
  /// - Returns: The item with the blocks and values added.
  func addingModifier(willInsert: ((Renderable, RenderableInsertContext) -> Void)?,
                      didInsert: ((Renderable, RenderableInsertContext) -> Void)?,
                      willUpdate: ((Renderable, RenderableUpdateContext) -> Void)?,
                      updates: AdditionalUpdates,
                      willRemove: ((Renderable, RenderableRemoveContext) -> Void)?,
                      didRemove: ((Renderable, RenderableRemoveContext) -> Void)?,
                      reuseId: String?,
                      resetForReuse: ((Renderable) -> Void)?,
                      transition: RenderableTransition?,
                      animationTiming: AnimationTiming?,
                      zIndex: CGFloat?) -> Self
  {
    addingModifierBlocks(
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      updates: updates,
      willRemove: willRemove,
      didRemove: didRemove,
      reuseId: reuseId,
      resetForReuse: resetForReuse,
      transition: transition,
      animationTiming: animationTiming,
      zIndex: zIndex
    )
  }
}

private extension RenderItem {

  /// Adds a modifier's blocks and values, see `addingModifier(willInsert:didInsert:willUpdate:updates:willRemove:didRemove:reuseId:resetForReuse:transition:animationTiming:zIndex:)`.
  ///
  /// This is generic code, where a block that takes `T` has the representation the storage keeps its blocks in, so the
  /// blocks made here are stored as they are, while a block made where `T` is `Renderable` is converted through a
  /// reabstraction thunk when stored. Only `addingModifier` calls it, so `T` is `Renderable` and the casts do nothing.
  func addingModifierBlocks(willInsert: ((Renderable, RenderableInsertContext) -> Void)?,
                            didInsert: ((Renderable, RenderableInsertContext) -> Void)?,
                            willUpdate: ((Renderable, RenderableUpdateContext) -> Void)?,
                            updates: AdditionalUpdates,
                            willRemove: ((Renderable, RenderableRemoveContext) -> Void)?,
                            didRemove: ((Renderable, RenderableRemoveContext) -> Void)?,
                            reuseId: String?,
                            resetForReuse: ((Renderable) -> Void)?,
                            transition: RenderableTransition?,
                            animationTiming: AnimationTiming?,
                            zIndex: CGFloat?) -> Self
  {
    // the storage is made here instead of through `with(...)`, which would copy each of the item's blocks and values
    // again, since a modifier's values aren't known when the code is compiled, as a builder's are
    let storage = storage

    var newWillInsert = storage.willInsert
    if let willInsert {
      let itemWillInsert = newWillInsert
      newWillInsert = { renderable, context in
        itemWillInsert?(renderable, context)
        willInsert(renderable as! Renderable, context) // swiftlint:disable:this force_cast
      }
    }
    var newDidInsert = storage.didInsert
    if let didInsert {
      let itemDidInsert = newDidInsert
      newDidInsert = { renderable, context in
        itemDidInsert?(renderable, context)
        didInsert(renderable as! Renderable, context) // swiftlint:disable:this force_cast
      }
    }
    var newWillUpdate = storage.willUpdate
    if let willUpdate {
      let itemWillUpdate = newWillUpdate
      newWillUpdate = { renderable, context in
        itemWillUpdate?(renderable, context)
        willUpdate(renderable as! Renderable, context) // swiftlint:disable:this force_cast
      }
    }
    var newWillRemove = storage.willRemove
    if let willRemove {
      let itemWillRemove = newWillRemove
      newWillRemove = { renderable, context in
        itemWillRemove?(renderable, context)
        willRemove(renderable as! Renderable, context) // swiftlint:disable:this force_cast
      }
    }
    var newDidRemove = storage.didRemove
    if let didRemove {
      let itemDidRemove = newDidRemove
      newDidRemove = { renderable, context in
        itemDidRemove?(renderable, context)
        didRemove(renderable as! Renderable, context) // swiftlint:disable:this force_cast
      }
    }
    var newResetForReuse = storage.resetForReuse
    if let resetForReuse {
      let itemResetForReuse = newResetForReuse
      newResetForReuse = { renderable in
        itemResetForReuse?(renderable)
        resetForReuse(renderable as! Renderable) // swiftlint:disable:this force_cast
      }
    }

    var newReuseId = storage.reuseId
    if let reuseId, newReuseId?.namespace != .user {
      newReuseId = ReuseId(namespace: .user, id: reuseId)
    }

    return Self(
      id: id,
      frame: frame,
      storage: Storage(
        source: storage.source,
        willInsert: newWillInsert,
        didInsert: newDidInsert,
        willUpdate: newWillUpdate,
        update: storage.update,
        additionalUpdates: storage.additionalUpdates.adding(contentsOf: updates),
        willRemove: newWillRemove,
        didRemove: newDidRemove,
        reuseId: newReuseId,
        renderableType: storage.renderableType,
        resetForReuse: newResetForReuse,
        transition: storage.transition ?? transition,
        animationTiming: storage.animationTiming ?? animationTiming,
        zIndex: zIndex ?? storage.zIndex
      )
    )
  }
}

public extension ViewItem {

  /// Erase the view item to a generic `RenderableItem`.
  ///
  /// - Returns: The erased renderable item.
  func eraseToRenderableItem() -> RenderableItem {
    RenderableItem(erasing: self)
  }
}

public extension LayerItem {

  /// Erase the layer item to a generic `RenderableItem`.
  ///
  /// - Returns: The erased renderable item.
  func eraseToRenderableItem() -> RenderableItem {
    RenderableItem(erasing: self)
  }
}

private extension RenderItem where T == Renderable {

  /// Makes an item that makes the view or layer item's renderables and runs its blocks.
  ///
  /// The erased item keeps the item's storage and calls it for the item's blocks, see `Source.typedItem`, instead of
  /// wrapping each block in a closure that casts the renderable to the item's type, which allocates a closure for each
  /// block. Only the update is wrapped, since the render pass runs it on every update of the renderable, and a call
  /// through the item's storage runs unspecialized, with a slower cast.
  ///
  /// - Parameter item: The view or layer item to erase.
  init<Item: NSObject>(erasing item: RenderItem<Item>) {
    let typedStorage = item.storage
    self.init(
      id: item.id,
      frame: item.frame,
      storage: Storage(
        source: .typedItem(typedStorage, blocks: typedStorage.blocks),
        willInsert: nil,
        didInsert: nil,
        willUpdate: nil,
        update: { renderable, context in
          typedStorage.performUpdate(RenderItem<Item>.Storage.itemRenderable(renderable), context)
        },
        additionalUpdates: .none,
        willRemove: nil,
        didRemove: nil,
        reuseId: item.reuseId,
        renderableType: ObjectIdentifier(Item.self),
        resetForReuse: nil,
        transition: item.transition,
        animationTiming: item.animationTiming,
        zIndex: item.zIndex
      )
    )
  }
}

// MARK: - TypedItemStorage

/// The storage of a view or layer item, which a `RenderableItem` erased from the item makes its renderables and runs
/// its lifecycle blocks through, see `RenderItem.Source.typedItem`.
private protocol TypedItemStorage: AnyObject {

  /// Makes a renderable with the item's `make` block.
  func makeErased(_ context: RenderableMakeContext) -> Renderable

  /// Runs the item's `willInsert` block, if any.
  func performWillInsert(erased renderable: Renderable, _ context: RenderableInsertContext)

  /// Runs the item's `didInsert` block, if any.
  func performDidInsert(erased renderable: Renderable, _ context: RenderableInsertContext)

  /// Runs the item's `willUpdate` block, if any.
  func performWillUpdate(erased renderable: Renderable, _ context: RenderableUpdateContext)

  /// Runs the item's `willRemove` block, if any.
  func performWillRemove(erased renderable: Renderable, _ context: RenderableRemoveContext)

  /// Runs the item's `didRemove` block, if any.
  func performDidRemove(erased renderable: Renderable, _ context: RenderableRemoveContext)

  /// Runs the item's `resetForReuse` block, if any.
  func performResetForReuse(erased renderable: Renderable)
}

/// The kinds of lifecycle blocks a view or layer item has, which the item erased from it keeps, so that it calls the
/// item's storage only for a block the item has, see `RenderItem.Source.typedItem`.
private struct TypedItemBlocks: OptionSet {

  let rawValue: UInt8

  static let willInsert = TypedItemBlocks(rawValue: 1 << 0)
  static let didInsert = TypedItemBlocks(rawValue: 1 << 1)
  static let willUpdate = TypedItemBlocks(rawValue: 1 << 2)
  static let willRemove = TypedItemBlocks(rawValue: 1 << 3)
  static let didRemove = TypedItemBlocks(rawValue: 1 << 4)
  static let resetForReuse = TypedItemBlocks(rawValue: 1 << 5)
}

// a view or layer item's source is its own `make` block, never a typed item, so it runs its own blocks
extension RenderItem.Storage: TypedItemStorage where T: NSObject {

  /// The kinds of lifecycle blocks the item has.
  var blocks: TypedItemBlocks {
    var blocks: TypedItemBlocks = []
    if willInsert != nil {
      blocks.insert(.willInsert)
    }
    if didInsert != nil {
      blocks.insert(.didInsert)
    }
    if willUpdate != nil {
      blocks.insert(.willUpdate)
    }
    if willRemove != nil {
      blocks.insert(.willRemove)
    }
    if didRemove != nil {
      blocks.insert(.didRemove)
    }
    if resetForReuse != nil {
      blocks.insert(.resetForReuse)
    }
    return blocks
  }

  func makeErased(_ context: RenderableMakeContext) -> Renderable {
    let renderable = makeRenderable(context)
    if let view = renderable as? View {
      return .view(view)
    } else {
      // only a view item and a layer item can be erased, so a renderable that isn't a view is a layer
      return .layer(renderable as! CALayer) // swiftlint:disable:this force_cast
    }
  }

  func performWillInsert(erased renderable: Renderable, _ context: RenderableInsertContext) {
    willInsert?(Self.itemRenderable(renderable), context)
  }

  func performDidInsert(erased renderable: Renderable, _ context: RenderableInsertContext) {
    didInsert?(Self.itemRenderable(renderable), context)
  }

  func performWillUpdate(erased renderable: Renderable, _ context: RenderableUpdateContext) {
    willUpdate?(Self.itemRenderable(renderable), context)
  }

  func performWillRemove(erased renderable: Renderable, _ context: RenderableRemoveContext) {
    willRemove?(Self.itemRenderable(renderable), context)
  }

  func performDidRemove(erased renderable: Renderable, _ context: RenderableRemoveContext) {
    didRemove?(Self.itemRenderable(renderable), context)
  }

  func performResetForReuse(erased renderable: Renderable) {
    resetForReuse?(Self.itemRenderable(renderable))
  }

  /// The renderable as the item's type.
  static func itemRenderable(_ renderable: Renderable) -> T {
    switch renderable {
    case .view(let view):
      // a layer item takes a view's layer, as `Renderable.layer` gives a layer for a view too
      return (view as? T) ?? (view.layer() as! T) // swiftlint:disable:this force_cast
    case .layer(let layer):
      return layer as! T // swiftlint:disable:this force_cast
    }
  }
}
