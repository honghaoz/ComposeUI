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
  /// moves out serve the rows that it moves in where they are, instead of being removed from their superview and added
  /// back from the pool. Removing a view and adding it back calls the superview and window callbacks of the view and
  /// its subviews, and on macOS, makes AppKit display it again, while moving it among its siblings does neither. The
  /// pass keeps views from the start of its removals to the end of its insertions, see `startKeeping()` and
  /// `stopKeeping(addingTo:)`, and the views that no insertion takes are removed then, for the pool.
  ///
  /// Only the views whose reuse identifier allows it stay in place, see `canKeep(_:key:)`. ComposeUI's own views allow
  /// it, since ComposeUI makes and resets them itself. An app's view can rely on being removed in ways that ComposeUI
  /// can't check, so its identifier allows it only when the app passes `inPlace: true` to `reuseId(_:inPlace:)`.
  ///
  /// On macOS, a view of one of ComposeUI's own reuse identifiers that passes every click through, which no insertion
  /// took, stays in place, hidden, for the insertions of later passes, up to `maxHiddenViewCount` of a kind, see
  /// `ClickThroughView`: a scroll leaves views over or lacks them in most steps, as the rows that it moves out and in
  /// differ, and each view that leaves the content view or comes back makes AppKit build the layer tree of the window's
  /// views again.
  ///
  /// It's a class that the view keeps in a constant, instead of a structure in a variable, since each call on a
  /// structure in a variable of the view checks at run time that no other access to the variable overlaps it, which
  /// costs more than the call itself in a pass that keeps no view.
  final class InPlaceReuse {

    /// The kept views, by their reuse keys. The emptied arrays of up to `maxKeyCount` keys stay with their capacity,
    /// instead of being removed, so that a steady scroll keeps and takes views without allocating.
    private var renderables: [ReuseKey: [Renderable]] = [:]

    /// The number of keys up to which `renderables` keeps the emptied arrays, as many as the pool keeps by default.
    static let maxKeyCount = 64

    #if DEBUG
    /// The number of keys in `renderables`, for tests.
    var keyCount: Int {
      renderables.count
    }
    #endif

    /// The number of kept views, which lets a pass that keeps none skip the lookups.
    private var count = 0

    /// Whether a key that the pass added took `renderables` past `maxKeyCount`.
    private var isOverKeyLimit = false

    /// Whether the removals keep their views, between `startKeeping()` and `stopKeeping(addingTo:)`.
    private var isKeeping = false

    #if canImport(AppKit)
    /// The views that pass every click through, which earlier passes kept and no insertion took, hidden in place, by
    /// their reuse keys.
    ///
    /// Only the views of ComposeUI's own reuse identifiers stay hidden, so the keys are few, and their emptied arrays
    /// stay. A hidden view takes no clicks, and assistive technologies skip it.
    private var hiddenRenderables: [ReuseKey: [Renderable]] = [:]

    /// The number of hidden views, which lets a take skip the lookup when there's none.
    private var hiddenCount = 0

    /// The number of views of a kind up to which the views that pass every click through stay hidden in place, past
    /// which they go to the pool.
    ///
    /// A steady scroll leaves over as many views of a kind as the number of shown views of the kind drops by, a few per
    /// row, so the limit leaves room for rows of several such views, while it bounds the views that a compose view keeps
    /// out of the pool.
    static let maxHiddenViewCount = 8

    /// Whether a memory warning removes the hidden views, which the in-place reuse arranges when it first hides a view.
    private var isObservingMemoryWarnings = false

    /// Returns whether a mouse button is pressed.
    private let isMouseButtonPressed: () -> Bool

    /// Whether a mouse button is pressed during the pass, read when a view first needs it, `nil` until then.
    private var isMouseButtonPressedInPass: Bool?

    /// Creates an in-place reuse that keeps no views yet.
    ///
    /// - Parameter isMouseButtonPressed: Returns whether a mouse button is pressed. Default reads
    ///   `NSEvent.pressedMouseButtons`.
    init(isMouseButtonPressed: @escaping () -> Bool = { NSEvent.pressedMouseButtons != 0 }) {
      self.isMouseButtonPressed = isMouseButtonPressed
    }
    #endif

    // MARK: - Render Pass

    /// Starts keeping the views that the render pass's removals leave, before the removals.
    ///
    /// - Parameter hasPool: Whether the compose view has a pool, without which it reuses no view, so the views that stay
    ///   hidden from earlier passes are removed first. It's an autoclosure, read only when views stay hidden, since
    ///   reading the compose view's pool costs more than the rest of the call.
    func startKeeping(hasPool: @autoclosure () -> Bool = true) {
      isKeeping = true
      #if canImport(AppKit)
      isMouseButtonPressedInPass = nil
      if hiddenCount > 0, !hasPool() {
        removeHiddenViews()
      }
      #endif
    }

    /// Stops keeping views, and removes the kept views, which no insertion took, from their parent, adding them to a
    /// pool. On macOS, the views that pass every click through stay in place, hidden, instead, up to
    /// `maxHiddenViewCount` of a kind.
    ///
    /// - Parameter pool: The pool, or `nil` to release the views. It's an autoclosure, read only when a view leaves for
    ///   it, since reading the compose view's pool for a plain argument costs more than the rest of the call in a pass
    ///   that keeps no view.
    func stopKeeping(addingTo pool: @autoclosure () -> RenderablePoolType?) {
      isKeeping = false

      if count > 0 {
        var leavingPool: RenderablePoolType?
        var hasReadPool = false

        // the index advances by hand, instead of iterating `renderables.indices`, which holds the dictionary's storage,
        // so emptying an array in the loop would copy the whole dictionary
        var index = renderables.startIndex
        while index != renderables.endIndex {
          let key = renderables.keys[index]
          for renderable in renderables.values[index] {
            #if canImport(AppKit)
            if hide(renderable, key: key) {
              continue
            }
            #endif
            renderable.removeFromParent()
            if !hasReadPool {
              leavingPool = pool()
              hasReadPool = true
            }
            leavingPool?.enqueue(renderable, key: key)
          }
          renderables.values[index].removeAll(keepingCapacity: true)
          renderables.formIndex(after: &index)
        }
        count = 0
      }

      // an app can give each item a reuse identifier of its own, so the emptied arrays would add up without a limit.
      // they go at the end of the pass, when they're all empty, since the views stay in them until then
      if isOverKeyLimit {
        isOverKeyLimit = false
        renderables.removeAll()
      }
    }

    // MARK: - Views

    /// Returns whether a reusable renderable that leaves can stay in place, for an insertion of its kind in the pass.
    ///
    /// Only a view whose reuse identifier allows it stays, and only while the pass keeps views.
    ///
    /// - Parameters:
    ///   - renderable: The renderable that leaves.
    ///   - key: The renderable's reuse key.
    /// - Returns: Whether the renderable can stay in place.
    func canKeep(_ renderable: Renderable, key: ReuseKey) -> Bool {
      guard isKeeping, key.reuseId.reusesInPlace else {
        return false
      }

      switch renderable {
      case .view(let view):
        return canKeep(view: view)
      case .layer:
        // a layer is removed and added back without callbacks, so the pool serves it as well
        return false
      }
    }

    /// Keeps a view for an insertion of its kind later in the pass.
    ///
    /// - Parameters:
    ///   - renderable: The view, reset for its reuse.
    ///   - key: The view's reuse key.
    func keep(_ renderable: Renderable, key: ReuseKey) {
      if let index = renderables.index(forKey: key) {
        renderables.values[index].append(renderable)
      } else {
        renderables[key] = [renderable]
        if renderables.count > Self.maxKeyCount {
          isOverKeyLimit = true
        }
      }
      count += 1
    }

    /// Takes a kept view of a kind: one that a removal in the pass left in place, or on macOS, one that stays hidden from
    /// an earlier pass, which shows again.
    ///
    /// - Parameter key: The reuse key.
    /// - Returns: A kept view, or `nil` if there's none of the kind.
    func take(_ key: ReuseKey) -> Renderable? {
      if count > 0, let index = renderables.index(forKey: key), let renderable = renderables.values[index].popLast() {
        count -= 1
        return renderable
      } else {
        return takeHidden(key)
      }
    }

    /// Takes a view of a kind that stays hidden from an earlier pass, which shows again.
    ///
    /// - Parameter key: The reuse key.
    /// - Returns: A hidden view, or `nil` if there's none of the kind.
    private func takeHidden(_ key: ReuseKey) -> Renderable? {
      #if canImport(AppKit)
      guard hiddenCount > 0,
            let index = hiddenRenderables.index(forKey: key),
            let renderable = hiddenRenderables.values[index].popLast()
      else {
        return nil
      }
      hiddenCount -= 1
      renderable.view?.isHidden = false
      return renderable
      #else
      return nil
      #endif
    }

    #if canImport(AppKit)
    /// Hides a kept view of one of ComposeUI's own reuse identifiers that passes every click through in place, for an
    /// insertion of its kind in a later pass, while fewer than `maxHiddenViewCount` views of its kind are hidden.
    ///
    /// - Parameters:
    ///   - renderable: The kept view, which no insertion took.
    ///   - key: The view's reuse key.
    /// - Returns: Whether the view stays hidden in place.
    private func hide(_ renderable: Renderable, key: ReuseKey) -> Bool {
      switch key.reuseId.namespace {
      case .framework:
        break
      case .user:
        // an app can give each item a reuse identifier of its own, so its views leave for the pool instead of staying
        // hidden without a limit
        return false
      }

      guard let view = renderable.view, view is ClickThroughView else {
        return false
      }

      if let index = hiddenRenderables.index(forKey: key) {
        guard hiddenRenderables.values[index].count < Self.maxHiddenViewCount else {
          return false
        }
        hiddenRenderables.values[index].append(renderable)
      } else {
        hiddenRenderables[key] = [renderable]
      }
      view.isHidden = true
      hiddenCount += 1

      if !isObservingMemoryWarnings {
        isObservingMemoryWarnings = true
        Self.observeMemoryWarnings(for: self)
      }
      return true
    }

    /// Removes the hidden views from their parent, and releases them.
    private func removeHiddenViews() {
      for views in hiddenRenderables.values {
        for renderable in views {
          renderable.view?.isHidden = false
          renderable.removeFromParent()
        }
      }
      hiddenRenderables.removeAll()
      hiddenCount = 0
    }

    // MARK: - Memory Warnings

    /// A reference to an in-place reuse that doesn't keep it alive.
    private struct WeakReference {

      weak var reuse: InPlaceReuse?
    }

    /// The in-place reuses that hid views, whose hidden views a memory warning removes.
    ///
    /// One handler serves them all, since the memory warning handlers stay for the life of the process, while compose
    /// views come and go.
    private static var memoryWarningObservers: [WeakReference] = []

    /// Whether the handler that removes the hidden views on a memory warning is added.
    private static var isHandlingMemoryWarnings = false

    /// Makes a memory warning remove an in-place reuse's hidden views.
    private static func observeMemoryWarnings(for reuse: InPlaceReuse) {
      if !isHandlingMemoryWarnings {
        isHandlingMemoryWarnings = true
        MemoryWarning.addHandler(removeObservedHiddenViews)
      }
      // the in-place reuses released since go first, so that the list doesn't grow with each compose view that the
      // process makes
      memoryWarningObservers.removeAll { $0.reuse == nil }
      memoryWarningObservers.append(WeakReference(reuse: reuse))
    }

    /// Removes the hidden views of the in-place reuses that hid views.
    private static func removeObservedHiddenViews() {
      for observer in memoryWarningObservers {
        observer.reuse?.removeHiddenViews()
      }
      memoryWarningObservers.removeAll { $0.reuse == nil }
    }
    #endif

    /// Returns whether a view can stay in place.
    ///
    /// A view that stays isn't removed from its window, so it gives up the first responder in it, as a removal would, and
    /// a view with an interaction in progress, which a removal would end, is removed as before.
    ///
    /// - Parameter view: The view.
    /// - Returns: Whether the view can stay in place.
    private func canKeep(view: View) -> Bool {
      #if canImport(AppKit)
      // AppKit takes the first responder away from a view that's removed from its window, while `makeFirstResponder(nil)`
      // only asks it to resign, which it can refuse, so a view with the first responder inside is removed as before. this
      // covers an editing text field too, since AppKit puts the field editor that edits it inside it
      if let firstResponder = view.window?.firstResponder as? NSView, firstResponder.isDescendant(of: view) {
        return false
      }

      // a pressed mouse button can be tracking in the view, which a removal would end, and AppKit doesn't tell
      // which view tracks, so no view stays while a button is pressed. the button state is read once per pass, when a
      // view first needs it, since reading it costs more than the rest of the check
      let isMouseButtonPressed = isMouseButtonPressedInPass ?? isMouseButtonPressed()
      isMouseButtonPressedInPass = isMouseButtonPressed
      return !isMouseButtonPressed
      #endif

      #if canImport(UIKit)
      // a touch that the view tracks, which a removal would cancel, or the focus, which a removal would move, would go on
      // with the view's next item, so a view with either is removed as before
      if Self.hasInteractionInProgress(view) {
        return false
      }

      view.endEditing(true)
      return true
      #endif
    }

    #if canImport(UIKit)
    /// Returns whether a view or a view in it has an interaction in progress: the focus, or a touch that a control or a
    /// gesture recognizer tracks.
    ///
    /// - Parameter view: The view.
    /// - Returns: Whether an interaction is in progress in the view.
    private static func hasInteractionInProgress(_ view: UIView) -> Bool {
      if view.isFocused {
        return true
      }
      if let control = view as? UIControl, control.isTracking {
        return true
      }
      if view.gestureRecognizers?.contains(where: { $0.numberOfTouches > 0 }) == true {
        return true
      }
      return view.subviews.contains { hasInteractionInProgress($0) }
    }
    #endif
  }
}
