//
//  SharedAnimationReads.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/10/26.
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

import QuartzCore

/// One read of a layer's animations, which the lookups of a render item's updates share, so that the built-in property
/// updates of different properties don't each read them, see `CALayer.animationSequence(forKeyPath:)`.
///
/// A lookup reads the layer's animation keys, which Core Animation copies into a new array, and looks up the animation of
/// each key, so updates of several properties of an animating layer would read its animations once each. In
/// `performUpdates(_:)`, the first built-in property update starts sharing the reads of its layer, see
/// `startSharing(for:)`, the first lookup then reads the animations, and the next lookups filter that read.
///
/// The read can only go stale for the key paths whose animations changed since it, so a lookup of such a key path, or of
/// one related to it, such as `position` for `position.x`, reads the layer itself:
/// - A lookup that finds animations marks its key path, since its caller can then remove them. A lookup's caller changes
///   only the animations of the key path it looked up, and an animation that changes it through another key path, such
///   as a group, which a lookup returns as `KeyPathAnimation.indirect`, is never removed.
/// - An animation added through `CALayer.animate(key:keyPath:timing:from:to:model:updateAnimation:)`, which the
///   property updates add theirs through, marks its key path, see `noteAnimationAdded(to:keyPath:)`. Path and frame
///   animations are added elsewhere, outside a render item's updates.
/// - Code that can change the animations without the framework knowing, such as a caller's update block, runs with the
///   lookups reading the layers themselves, and drops the read, see `performUnshared(_:)`.
///
/// Like the render pass, it must be used on the main thread only.
enum SharedAnimationReads {

  /// An animation of the layer, read once with what a lookup of a key path checks.
  struct Animation {

    /// The animation's key.
    let key: String

    /// The animation, as the layer returned it for the key.
    let animation: CAAnimation?

    /// The animation as a property animation, `nil` for an animation of another kind, such as a group.
    let propertyAnimation: CAPropertyAnimation?

    /// The property animation's key path.
    let keyPath: String?
  }

  /// How a lookup of a layer's animations reads them.
  enum Lookup {

    /// The lookup reads the layer itself.
    case live

    /// The lookup filters the shared read: the sequence of the animations that change the key path, or `nil` when none
    /// does.
    case shared(KeyPathAnimationSequence?)
  }

  /// The state of the updates that share a read.
  private struct State {

    /// Whether a render item's updates are running, see `performUpdates(_:)`.
    var isActive = false

    /// The layer whose lookups share a read, `nil` until a property update starts sharing, see `startSharing(for:)`.
    var layer: ObjectIdentifier?

    /// Whether the lookups read the layers themselves for now, see `performUnshared(_:)`.
    var isSuspended = false

    /// Whether `animations` holds the layer's animations, which the first shared lookup reads.
    var hasRead = false

    /// The layer's animations, in the layer's animation key order.
    ///
    /// The array keeps its capacity from read to read, so a read allocates only the keys array that Core Animation
    /// makes.
    var animations: [Animation] = []

    /// The key paths whose animations may have changed since the read, see `SharedAnimationReads`.
    var changedKeyPaths: [String] = []
  }

  /// The state, in memory that the type manages instead of a static variable, every access to which the compiler
  /// checks at run time.
  private static let state: UnsafeMutablePointer<State> = {
    let pointer = UnsafeMutablePointer<State>.allocate(capacity: 1)
    pointer.initialize(to: State())
    return pointer
  }()

  /// Runs a render item's updates, whose lookups share one read of the animations of the layer that the first built-in
  /// property update sets, see `startSharing(for:)`.
  ///
  /// The updates must not change the layer's animations other than through the framework's lookups and animations,
  /// except in `performUnshared(_:)`.
  ///
  /// - Parameter body: The updates to run.
  static func performUpdates(_ body: () -> Void) {
    guard !state.pointee.isActive else {
      // the state holds one layer's read, so the updates of an item updated from these updates read their layer itself
      body()
      return
    }

    state.pointee.isActive = true
    defer {
      state.pointee.isActive = false
      state.pointee.layer = nil
      dropRead()
    }
    body()
  }

  /// Starts sharing the reads of the renderable's layer, for a built-in property update in `performUpdates(_:)`.
  ///
  /// The first property update starts sharing, instead of `performUpdates(_:)`, so that updates that set no property,
  /// such as on a scroll, which most properties skip, don't pay for it. A view that isn't layer-backed has no animations
  /// to share.
  ///
  /// - Parameter renderable: The renderable that the property update sets.
  static func startSharing(for renderable: Renderable) {
    guard state.pointee.isActive, state.pointee.layer == nil, let layer = renderable.existingLayer else {
      return
    }
    state.pointee.layer = ObjectIdentifier(layer)
  }

  /// Runs code in `performUpdates(_:)` that can change a layer's animations without the framework knowing, such as a
  /// caller's update block, with lookups that read the layers themselves, and drops the shared read afterwards, since it
  /// may no longer match the layer.
  ///
  /// - Parameter body: The code to run.
  /// - Returns: What the code returns.
  static func performUnshared<Result>(_ body: () -> Result) -> Result {
    // before a property update starts sharing, lookups read the layers themselves anyway
    guard state.pointee.layer != nil, !state.pointee.isSuspended else {
      return body()
    }

    state.pointee.isSuspended = true
    defer {
      state.pointee.isSuspended = false
      dropRead()
    }
    return body()
  }

  /// How a lookup of the layer's animations of the key path reads them.
  ///
  /// - Parameters:
  ///   - layer: The layer.
  ///   - keyPath: The looked up key path.
  /// - Returns: `.shared` with the animations from the shared read, or `.live` when the lookup reads the layer itself:
  ///   for another layer, outside a shared read, in `performUnshared(_:)`, or for a key path whose animations may have
  ///   changed since the read.
  static func lookUp(_ layer: CALayer, keyPath: String) -> Lookup {
    guard state.pointee.layer == ObjectIdentifier(layer), !state.pointee.isSuspended, !mayHaveChanged(keyPath) else {
      return .live
    }

    if !state.pointee.hasRead {
      read(layer)
    }
    let animations = KeyPathAnimationSequence(sharedAnimations: state.pointee.animations, keyPath: keyPath)
    // matched instead of compared with `nil`, which copies the sequence and its array
    switch animations {
    case .some:
      state.pointee.changedKeyPaths.append(keyPath)
    case .none:
      break
    }
    return .shared(animations)
  }

  /// Marks the key path as changed, after an animation of it is added to the layer.
  ///
  /// - Parameters:
  ///   - layer: The layer.
  ///   - keyPath: The animated key path.
  static func noteAnimationAdded(to layer: CALayer, keyPath: String) {
    // before the read, the read sees the animation
    guard state.pointee.hasRead, state.pointee.layer == ObjectIdentifier(layer), !mayHaveChanged(keyPath) else {
      return
    }
    state.pointee.changedKeyPaths.append(keyPath)
  }

  /// Whether the key path's animations may have changed since the read: it's a changed key path, or a component of one,
  /// or one is its component.
  private static func mayHaveChanged(_ keyPath: String) -> Bool {
    state.pointee.changedKeyPaths.contains { changedKeyPath in
      changedKeyPath == keyPath
        || KeyPathAnimationSequence.isKeyPath(keyPath, aComponentOf: changedKeyPath)
        || KeyPathAnimationSequence.isKeyPath(changedKeyPath, aComponentOf: keyPath)
    }
  }

  /// Reads the layer's animations.
  private static func read(_ layer: CALayer) {
    if let keys = layer.unbridgedAnimationKeys {
      for index in keys.indices {
        let key = keys[index]
        let animation = layer.animation(forKey: key)
        let propertyAnimation = animation as? CAPropertyAnimation
        state.pointee.animations.append(Animation(key: key, animation: animation, propertyAnimation: propertyAnimation, keyPath: propertyAnimation?.keyPath))
      }
    }
    state.pointee.hasRead = true
  }

  /// Drops the read and the changed key paths, if there is a read, keeping the arrays' capacity.
  ///
  /// Without a read, there are no changed key paths either, since only a shared lookup, which reads, or an animation
  /// added after the read marks one.
  private static func dropRead() {
    guard state.pointee.hasRead else {
      return
    }
    state.pointee.hasRead = false
    state.pointee.animations.removeAll(keepingCapacity: true)
    state.pointee.changedKeyPaths.removeAll(keepingCapacity: true)
  }
}
