//
//  ComposeView.swift
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

import Combine

/// A view that renders `ComposeContent`.
///
/// ## Content Lifecycle
///
/// The content builder runs on refresh: an explicit `refresh()` or `setNeedsRefresh()`, or an environment change such
/// as a window or display scale change. A bounds change (resize or scroll) lays out the retained content again without
/// running the builder, so changed application data shows only after a refresh. `sizeThatFits(_:)` measures the
/// builder's latest content, which may differ from the displayed content.
///
/// ## Z-Order
///
/// The content's renderables (views and layers) render in the items order: a later item renders above an earlier item,
/// regardless of the renderable's kind (view or layer).
///
/// The cross-kind render order is maintained with the renderable layers' `zPosition`: the render pass assigns each
/// renderable layer a `zPosition` composed of the item's z-index band (see `ComposeNode.zIndex(_:)`, defaulting to 0)
/// plus a small items-order fraction. A higher band always renders above a lower band. Within the same band, items
/// stack in the items order.
///
/// Notes:
/// - The render pass owns the managed renderable layers' `zPosition`. Use `ComposeNode.zIndex(_:)` to control the
///   stacking explicitly instead of setting `zPosition` directly.
/// - Hit-testing follows the subview order, which is kept in the items order among view items. Layer items never
///   hit-test, so a layer item rendering above a view item does not block the view item's interaction.
open class ComposeView: BaseScrollView {

  /// The default content when the view is initialized with `init(frame:)`.
  ///
  /// A `ComposeView` subclass can override this property to provide a different content.
  /// For example:
  ///
  /// ```swift
  /// class MyView: ComposeView {
  ///
  ///   @ComposeContentBuilder
  ///   override var content: ComposeContent {
  ///     VStack {
  ///       Text("Hello, World!")
  ///     }
  ///   }
  /// }
  /// ```
  open var content: ComposeContent {
    Empty()
  }

  // MARK: - Animation Behavior

  /// The animation behavior of the content update.
  public var animationBehavior: AnimationBehavior = .default

  /// The insets to apply to the visible bounds when determining which content to render.
  ///
  /// - Negative values expand the visible bounds in that direction, causing more content to be rendered.
  /// - Positive values shrink the visible bounds in that direction, causing less content to be rendered.
  ///
  /// The default value is zero for all edges, which means the visible bounds are not adjusted.
  public var visibleBoundsInsets = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

  // MARK: - Private

  /// The content builder.
  private var makeContent: (ComposeView) throws -> ComposeContent

  /// The root layout node for the current content.
  private var contentNode: LayoutCacheNode?

  /// The evaluation used to measure and render the current content.
  private var contentEvaluation: ContentEvaluation?

  /// Content a parent view prepared for the next refresh.
  private struct PreparedContent {

    /// The root layout node of the prepared content.
    let node: LayoutCacheNode

    /// The evaluation supplied with the prepared content, or nil to create a new one.
    let evaluation: ContentEvaluation?

    /// The parent's animation decision capping the refresh that applies the content.
    let animationDecision: AnimationDecision
  }

  /// The prepared content waiting to be applied by refresh.
  private var preparedContent: PreparedContent?

  /// The animation decision of the render pass in progress.
  private var renderingAnimationDecision: AnimationDecision?

  /// The context of the current content update.
  private var contentUpdateContext: ContentUpdateContext?

  /// The bounds from the last completed render pass, or nil before the first render.
  private var lastRenderBounds: CGRect?

  /// The view's size from the last completed render pass, or nil before the first render.
  private var lastBoundsSize: CGSize?

  /// The content insets from the last completed render pass, or nil before the first render.
  private var lastRenderInsets: EdgeInsets?

  /// The ids of the renderable items that are being rendered.
  private var renderableItemIds: [ComposeNodeId] = []

  /// The renderable items that are being rendered, in the order of `renderableItemIds`.
  private var renderableItems: [RenderableItem] = []

  /// The indices of the renderable items in `renderableItems`, by their ids.
  private var renderableItemIndexMap: [ComposeNodeId: Int] = [:]

  /// The map of the renderables that are being rendered.
  private var renderableMap: [ComposeNodeId: Renderable] = [:]

  /// The offset of the renderable items' z-position keys from their indices in the last render pass, see `ZOrderPass.keyOffset`.
  private var zPositionKeyOffset = 0

  /// A renderable with an in-flight removal.
  struct RemovingRenderable {

    /// The renderable being removed.
    let renderable: Renderable

    /// The transition animating the removal.
    let removeTransition: RenderableTransition.RemoveTransition

    /// The removal completion. Executing it finalizes the removal, cancelling it revives the renderable.
    let completion: CancellableBlock

    /// The z-index of the renderable's item.
    let zIndex: CGFloat?

    /// The z-position key of the renderable's layer, which a render pass moves along with the items' keys when it moves
    /// them to the middle of their range, so that the layer keeps its place among the items, see
    /// `ZOrderPass.moveKeys(ofRemovingRenderables:)`.
    var zPositionKey: Int
  }

  /// The key of a renderable with an in-flight removal: its item's id and renderable type, since only an item with the
  /// same id and renderable type can take the renderable back.
  struct RemovingRenderableKey: Hashable {

    /// The id of the renderable's item.
    let id: ComposeNodeId

    /// The renderable type of the renderable's item.
    let renderableType: ObjectIdentifier?
  }

  /// The map of the renderables that are being removed.
  ///
  /// The removing renderables are the ones that are not in the renderable hierarchy but still rendered due to the transition.
  private var removingRenderableMap: [RemovingRenderableKey: RemovingRenderable] = [:]

  /// The map of the inserting renderable transition completion blocks.
  private var insertingRenderableTransitionCompletionMap: [ComposeNodeId: CancellableBlock] = [:]

  /// The reusable views that the render pass's removals left in place, for its insertions.
  private let inPlaceReuse = InPlaceReuse()

  /// The pool that recycles renderables across render passes.
  ///
  /// By default, all `ComposeView`s share a single process-wide pool (`RenderablePool.shared`) so reuse is amortized
  /// across views.
  ///
  /// Assign a custom `RenderablePoolType` to plug in your own implementation or set it to `nil` to disable renderable reuse.
  public var renderablePool: RenderablePoolType? = RenderablePool.shared

  // MARK: - Initialization

  /// Creates a `ComposeView` with the given content.
  ///
  /// - Parameter content: A content builder with the host view as the parameter.
  public init(@ComposeContentBuilder content: @escaping (ComposeView) throws -> ComposeContent) {
    self.makeContent = content

    super.init(frame: .zero)

    commonInit()
  }

  /// Creates a `ComposeView` with the given content.
  ///
  /// - Parameter content: A content builder.
  public init(@ComposeContentBuilder content: @escaping () throws -> ComposeContent) {
    makeContent = { _ in try content() }

    super.init(frame: .zero)

    commonInit()
  }

  /// Creates a `ComposeView` with the given content.
  ///
  /// - Parameter content: The content.
  public convenience init(content: ComposeContent) {
    self.init { content }
  }

  /// Creates a `ComposeView` with `content` as the default content.
  ///
  /// You should either override `content` to provide the actual content or use `setContent()` to set the content later.
  override public init(frame: CGRect) {
    makeContent = { _ in Empty() }

    super.init(frame: frame)

    makeContent = { [unowned self] _ in content } // swiftlint:disable:this unowned_variable_capture
    commonInit()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  #if canImport(AppKit)
  override class func makeDocumentView() -> NSView {
    DocumentView()
  }
  #endif

  private func commonInit() {
    contentScaleFactor = windowScaleFactor

    #if canImport(AppKit)
    drawsBackground = false // make the view transparent
    automaticallyAdjustsContentInsets = false
    // AppKit clamps every way of magnifying to this range, including the animator's `magnify(toFit:)` and
    // `setMagnification(_:centeredAt:)`, which change the magnification without calling the overrides
    minMagnification = 1
    maxMagnification = 1

    // set the scroll indicators to be shown by default
    // this is to make the scroll indicators are visible immediately when scrolling for the first time
    showsHorizontalScrollIndicator = true
    showsVerticalScrollIndicator = true

    #if DEBUG
    if Thread.isRunningXCTest {
      // when running tests, the scroller may affect the scroll view's content size.
      // change the default scroll indicator behavior in tests to make the test more deterministic.
      scrollIndicatorBehavior = .never
      hasHorizontalScroller = false
      hasVerticalScroller = false
    }
    #endif

    #endif

    #if canImport(UIKit)
    // ensure the content inset is consistent regardless of the safe area
    contentInsetAdjustmentBehavior = .never
    #endif

    observeTheme()
  }

  // MARK: - Content

  /// Sets a new content.
  ///
  /// An animated refresh will be scheduled. To disable the animation, call `setNeedsRefresh(animated: false)` or `refresh(animated: false)`.
  ///
  /// - Parameter content: A content builder with the host view as the parameter.
  open func setContent(@ComposeContentBuilder content: @escaping (ComposeView) throws -> ComposeContent) {
    makeContent = content
    preparedContent = nil
    setNeedsRefresh()
  }

  /// Sets a new content.
  ///
  /// An animated refresh will be scheduled. To disable the animation, call `setNeedsRefresh(animated: false)` or `refresh(animated: false)`.
  ///
  /// - Parameter content: A content builder.
  open func setContent(@ComposeContentBuilder content: @escaping () throws -> ComposeContent) {
    setContent(content: { _ in try content() })
  }

  /// Sets a new content with a prepared content evaluation and refreshes immediately within the caller's render pass.
  ///
  /// This is used internally to set a prepared content from the parent ComposeView, so the child ComposeView can reuse
  /// the prepared content evaluation.
  ///
  /// - Parameters:
  ///   - content: A new content.
  ///   - contentEvaluation: The evaluation to reuse once, or nil to create a new one on refresh.
  ///   - animationDecision: The parent's resolved transition and update decisions.
  func setPreparedContent(_ content: ComposeNode, contentEvaluation: ContentEvaluation?, animationDecision: AnimationDecision) {
    makeContent = { _ in content }
    preparedContent = PreparedContent(
      node: LayoutCacheNode(node: content),
      evaluation: contentEvaluation,
      animationDecision: animationDecision
    )

    // trigger an immediate refresh
    // if the parent's render pass allows either transitions or update animations, this child view's content will be
    // rendered with animations, and the parent's decision caps the animations this view runs (see `render(_:)`).
    refresh(animated: animationDecision.allowsTransitions || animationDecision.allowsAnimations)
  }

  /// Makes the content node.
  private func _makeContent() -> ComposeNode {
    do {
      return try makeContent(self).asVStack()
    } catch {
      print("[ComposeUI] Failed to make content: \(error)")
      ComposeUI.assertFailure("Failed to make content: \(error)")
      return Empty()
    }
  }

  // MARK: - Render Handlers

  private var willLayoutHandler: ((_ view: ComposeView, _ context: WillLayoutContext) -> Void)?
  private var willRenderHandler: ((_ view: ComposeView, _ context: WillRenderContext) -> Void)?
  private var didRenderHandler: ((_ view: ComposeView, _ context: DidRenderContext) -> Void)?

  /// Set a handler to be called before layout.
  ///
  /// This handler runs before the content size is updated.
  ///
  /// It runs before each layout of a render pass. Usually, the layout is performed once, but on macOS, with the legacy
  /// scroll bar style (`NSScrollView.scrollerStyle == .legacy`), if the content is larger than the view's bounds, the
  /// layout is performed up to three times: for the full view size, for the view size minus the scroll bar width, and
  /// for the view size minus both scroll bars if the content then overflows along the other axis.
  ///
  /// This handler runs inside the render pass, so a refresh or layout it requests for this view, or for a view
  /// containing it, waits until the pass ends (see `refresh(animated:)`).
  ///
  /// The handler can adjust things like the content offset, but it can't change the view's size, its visible size or its
  /// scroll settings, such as `scrollBehavior`, `scrollIndicatorBehavior` or `clippingBehavior`, etc.
  ///
  /// Calling this replaces any previously set handler.
  ///
  /// - Parameter handler: The will-layout handler.
  /// - Returns: The ComposeView itself.
  @discardableResult
  public func onWillLayout(_ handler: @escaping (_ view: ComposeView, _ context: WillLayoutContext) -> Void) -> Self {
    willLayoutHandler = handler
    return self
  }

  /// Set a handler to be called after layout computed the content size and updated the scroll view's content size, but before renderable items are requested.
  ///
  /// This handler gives you a chance to adjust the content offset (which affects the visible bounds) before rendering.
  ///
  /// For example, for chat-like UI, you can use this handler to adjust the content offset to be at the bottom, so the renderable items are rendered from the bottom.
  ///
  /// You should not change the view's bounds size in this handler, otherwise an additional layout pass will be scheduled.
  ///
  /// This handler runs inside the render pass, so a refresh or layout it requests for this view, or for a view
  /// containing it, waits until the pass ends (see `refresh(animated:)`).
  ///
  /// Calling this replaces any previously set handler.
  ///
  /// - Parameter handler: The will-render handler.
  /// - Returns: The ComposeView itself.
  @discardableResult
  public func onWillRender(_ handler: @escaping (_ view: ComposeView, _ context: WillRenderContext) -> Void) -> Self {
    willRenderHandler = handler
    return self
  }

  /// Set a handler to be called at the end of the render pass, after all renderables are updated.
  ///
  /// At this point, all renderables have been placed with their new frames (model values updated), animations or
  /// transitions may still be running.
  ///
  /// This handler runs inside the render pass, so a refresh or layout it requests for this view, or for a view
  /// containing it, waits until the pass ends (see `refresh(animated:)`).
  ///
  /// Calling this replaces any previously set handler.
  ///
  /// - Parameter handler: The did-render handler.
  /// - Returns: The ComposeView itself.
  @discardableResult
  public func onDidRender(_ handler: @escaping (_ view: ComposeView, _ context: DidRenderContext) -> Void) -> Self {
    didRenderHandler = handler
    return self
  }

  // MARK: - Debug

  #if DEBUG
  private var debug: Debug?

  /// Set a debug handler to the ComposeView.
  ///
  /// - Parameter eventHandler: The event handler to handle the debug events.
  /// - Returns: The ComposeView itself.
  @discardableResult
  public func debug(eventHandler: @escaping (_ view: ComposeView, _ event: ComposeView.Debug.Event) -> Void) -> Self {
    debug = Debug(composeView: self, eventHandler: eventHandler)
    return self
  }

  /// Returns the renderable items that are being rendered, by their ids, for a debug event.
  ///
  /// It's never inlined, since the render pass calls it in the debug builds that the benchmarks use, where inlining the
  /// map's construction would change how the optimizer compiles the render pass.
  @inline(never)
  private func makeRenderableItemMap() -> [ComposeNodeId: RenderableItem] {
    Dictionary(uniqueKeysWithValues: zip(renderableItemIds, renderableItems))
  }
  #endif

  // MARK: - Size

  #if canImport(AppKit)
  /// Returns the size that fits the content and its content insets. This measures the latest content, it may not be the same as the displayed content.
  ///
  /// As in a render pass, the content lays out in the proposed size minus the insets.
  ///
  /// - Parameter size: The proposed size.
  /// - Returns: The size that fits the content and its insets.
  open func sizeThatFits(_ size: CGSize) -> CGSize {
    _sizeThatFits(size)
  }
  #endif

  #if canImport(UIKit)
  /// Returns the size that fits the content and its content insets. This measures the latest content, it may not be the same as the displayed content.
  ///
  /// As in a render pass, the content lays out in the proposed size minus the insets.
  ///
  /// - Parameter size: The proposed size.
  /// - Returns: The size that fits the content and its insets.
  override open func sizeThatFits(_ size: CGSize) -> CGSize {
    _sizeThatFits(size)
  }
  #endif

  private func _sizeThatFits(_ size: CGSize) -> CGSize {
    var contentNode = _makeContent()
    let context = ComposeNodeLayoutContext(scaleFactor: contentScaleFactor, contentEvaluation: ContentEvaluation())

    // the content lays out between the insets, as in a render pass, so the view fits it with the insets added back.
    // legacy scroll bars over the content only show when the content overflows, so the fitting size leaves them out
    let insets = contentInsetExcludingScrollBars
    let sizeBetweenInsets = Self.sizeBetweenInsets(insets, in: size)
    _ = contentNode.layout(containerSize: CGSize(width: max(sizeBetweenInsets.width, 0), height: max(sizeBetweenInsets.height, 0)), context: context)

    let fittingSize = CGSize(width: contentNode.size.width + insets.left + insets.right, height: contentNode.size.height + insets.top + insets.bottom)
    return fittingSize.roundedUp(scaleFactor: contentScaleFactor)
  }

  // MARK: - Scroll

  /// The view's scrollable behavior. The default value is `.auto`. Requires a refresh to take effect.
  public var scrollBehavior: ScrollBehavior = .auto

  /// The view's scroll indicator behavior. The default value is `.auto`. Requires a refresh to take effect.
  public var scrollIndicatorBehavior: ScrollIndicatorBehavior = .auto

  /// The scroll indicator behavior the scroll indicators were last updated for, or nil before the first render.
  private var lastScrollIndicatorBehavior: ScrollIndicatorBehavior?

  // MARK: - Clipping

  /// The view's clipping behavior. The default value is `.auto`. Requires a refresh to take effect.
  public var clippingBehavior: ClippingBehavior = .auto

  // MARK: - Theme

  private var themeObservation: AnyCancellable?

  private func observeTheme() {
    themeObservation = themePublisher.dropFirst().sink { [weak self] _ in
      self?.themeDidChange()
    }
  }

  private func themeDidChange() {
    restartPrefetching()
    setNeedsRefresh(animated: true)
  }

  // MARK: - Window

  #if canImport(AppKit)
  override open func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    _didMoveToWindow()
    startObservingWindow()
  }
  #endif

  #if canImport(UIKit)
  override open func didMoveToWindow() {
    super.didMoveToWindow()

    _didMoveToWindow()
  }
  #endif

  private weak var previousWindow: Window?

  private func _didMoveToWindow() {
    contentScaleFactor = windowScaleFactor

    // the items prepare their content for the window that shows it, so the view prepares it again in another window, and
    // keeps none out of a window
    if previousWindow != window {
      restartPrefetching()
    }

    if window != nil, previousWindow != window {
      setNeedsRefresh(animated: false) // schedule to refresh when the window is changed
    }
    previousWindow = window
  }

  // MARK: - Observing Window

  #if canImport(AppKit)
  private weak var observingWindow: NSWindow?
  private var observingDidBecomeKeyToken: Any?
  private var observingDidResignKeyToken: Any?
  private var observingDidBecomeActiveToken: Any?
  private var observingWindowBackingPropertiesToken: Any?
  private var windowColorSpaceObservation: NSKeyValueObservation?

  private func startObservingWindow() {
    guard let window else {
      // no window, stop observing
      stopObservingWindow()
      return
    }

    guard observingWindow != window else {
      // the window is the same as the current window, no need to observe
      return
    }

    stopObservingWindow()

    // update for future key window changes
    observingDidBecomeKeyToken = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification,
      object: window,
      queue: nil,
      using: { [weak self] _ in
        self?.keyWindowDidChange()
      }
    )

    observingDidResignKeyToken = NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification,
      object: window,
      queue: nil,
      using: { [weak self] _ in
        self?.keyWindowDidChange()
      }
    )

    // `NSWindow.didBecomeKeyNotification` can be missed sometimes, observe `NSApplication.didBecomeActiveNotification`
    // to make sure the key window state is reliably observed
    observingDidBecomeActiveToken = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: nil,
      using: { [weak self] _ in
        self?.keyWindowDidChange()
      }
    )

    observingWindowBackingPropertiesToken = NotificationCenter.default.addObserver(
      forName: NSWindow.didChangeBackingPropertiesNotification,
      object: window,
      queue: nil,
      using: { [weak self] _ in
        self?.windowBackingPropertiesDidChange()
      }
    )

    // AppKit posts the backing properties notification when the window takes a color space from its screen, but not when
    // the app sets one, so the view observes the color space too. key-value observing reports every set, even of the
    // color space that the window has, so only a different color space makes the view prefetch again
    windowColorSpaceObservation = window.observe(\.colorSpace, options: [.old, .new]) { [weak self] _, change in
      if change.oldValue != change.newValue {
        self?.restartPrefetching()
      }
    }

    observingWindow = window
  }

  private func stopObservingWindow() {
    if let observingDidBecomeKeyToken {
      NotificationCenter.default.removeObserver(observingDidBecomeKeyToken, name: NSWindow.didBecomeKeyNotification, object: observingWindow)
      self.observingDidBecomeKeyToken = nil
    }

    if let observingDidResignKeyToken {
      NotificationCenter.default.removeObserver(observingDidResignKeyToken, name: NSWindow.didResignKeyNotification, object: observingWindow)
      self.observingDidResignKeyToken = nil
    }

    if let observingDidBecomeActiveToken {
      NotificationCenter.default.removeObserver(observingDidBecomeActiveToken, name: NSApplication.didBecomeActiveNotification, object: nil)
      self.observingDidBecomeActiveToken = nil
    }

    if let observingWindowBackingPropertiesToken {
      NotificationCenter.default.removeObserver(observingWindowBackingPropertiesToken, name: NSWindow.didChangeBackingPropertiesNotification, object: observingWindow)
      self.observingWindowBackingPropertiesToken = nil
    }

    windowColorSpaceObservation?.invalidate()
    windowColorSpaceObservation = nil

    observingWindow = nil
    oldIsKeyWindow = false
  }

  private var oldIsKeyWindow: Bool = false

  private func keyWindowDidChange() {
    guard let window else {
      return
    }

    if window.isKeyWindow != oldIsKeyWindow {
      setNeedsRefresh(animated: false)
    }

    oldIsKeyWindow = window.isKeyWindow
  }

  private func windowBackingPropertiesDidChange() {
    // the window's scale or color space changed
    restartPrefetching()

    let oldContentScaleFactor = contentScaleFactor
    contentScaleFactor = windowScaleFactor

    if oldContentScaleFactor != contentScaleFactor {
      setNeedsRefresh(animated: false)
    }
  }
  #endif

  #if canImport(UIKit) && !os(visionOS)
  override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    // UIKit delivers display scale changes as trait changes (for example, when the window moves to a screen with a
    // different scale) and has no counterpart of AppKit's backing properties notification, so mirror
    // `windowBackingPropertiesDidChange()`: adopt the new scale, prefetch again, and re-render non-animated, so
    // rasterized contents and pixel rounding use the new scale instead of a stale one.
    //
    // visionOS is excluded because the content scale is pinned to the default scale factor there (see `windowScaleFactor`).

    let oldContentScaleFactor = contentScaleFactor
    // an unspecified trait collection reports a display scale of 0, clamp so the scale stays usable
    let newContentScaleFactor = max(traitCollection.displayScale, 1)

    if oldContentScaleFactor != newContentScaleFactor {
      contentScaleFactor = newContentScaleFactor
      restartPrefetching()
      setNeedsRefresh(animated: false)
    }
  }
  #endif

  #if canImport(AppKit)

  // MARK: - Tiling

  /// Final, because this method sets the visible size that the content lays out for.
  override public final func tile() {
    super.tile()

    // AppKit re-tiles without laying the view out when the scroller style changes or a scroll bar shows or hides, so ask
    // for a layout when that changes the visible size the content rendered for. a render pass renders for the visible
    // size its own re-tiles leave, and AppKit ignores the request during a layout, which renders next anyway.
    if !isRendering, boundsChangedSinceLastRender() {
      needsLayout = true
    }
  }

  // MARK: - Locked Scroll View Settings

  /// Always `false`, so the content insets stay the same under the window's title bar and toolbar.
  ///
  /// Setting it to `true` asserts and keeps it `false`.
  override public final var automaticallyAdjustsContentInsets: Bool {
    get {
      super.automaticallyAdjustsContentInsets
    }
    set {
      ComposeUI.assert(!newValue, "ComposeView doesn't support adjusting the content insets automatically")
      super.automaticallyAdjustsContentInsets = false
    }
  }

  /// Always `false`, since `ComposeView` doesn't support magnification.
  ///
  /// Setting it to `true` asserts and keeps it `false`.
  override public final var allowsMagnification: Bool {
    get {
      super.allowsMagnification
    }
    set {
      ComposeUI.assert(!newValue, "ComposeView doesn't support magnification")
    }
  }

  /// Always 1, since `ComposeView` doesn't support magnification.
  ///
  /// Setting another value asserts and keeps 1.
  override public final var magnification: CGFloat {
    get {
      super.magnification
    }
    set {
      ComposeUI.assert(newValue == 1, "ComposeView doesn't support magnification")
    }
  }

  /// Keeps the magnification at 1, since `ComposeView` doesn't support magnification. Another magnification asserts.
  override public final func setMagnification(_ magnification: CGFloat, centeredAt point: CGPoint) {
    ComposeUI.assert(magnification == 1, "ComposeView doesn't support magnification")
  }

  /// Keeps the magnification at 1 and asserts, since `ComposeView` doesn't support magnification.
  override public final func magnify(toFit rect: CGRect) {
    ComposeUI.assertFailure("ComposeView doesn't support magnification")
  }

  /// Always 1, since `ComposeView` doesn't support magnification.
  ///
  /// Setting another value asserts and keeps 1.
  override public final var minMagnification: CGFloat {
    get {
      super.minMagnification
    }
    set {
      ComposeUI.assert(newValue == 1, "ComposeView doesn't support magnification")
      super.minMagnification = 1
    }
  }

  /// Always 1, since `ComposeView` doesn't support magnification.
  ///
  /// Setting another value asserts and keeps 1.
  override public final var maxMagnification: CGFloat {
    get {
      super.maxMagnification
    }
    set {
      ComposeUI.assert(newValue == 1, "ComposeView doesn't support magnification")
      super.maxMagnification = 1
    }
  }

  /// Always `.noBorder`, since the content lays out for the view's whole bounds.
  ///
  /// Setting another border type asserts and keeps `.noBorder`.
  override public final var borderType: NSBorderType {
    get {
      super.borderType
    }
    set {
      ComposeUI.assert(newValue == .noBorder, "ComposeView doesn't support borders")
    }
  }

  /// Always `false`, since `ComposeView` shows and hides its scroll bars itself (see `scrollIndicatorBehavior`).
  ///
  /// Setting it to `true` asserts and keeps it `false`.
  override public final var autohidesScrollers: Bool {
    get {
      super.autohidesScrollers
    }
    set {
      // a legacy scroll bar that AppKit hides on its own changes the size the content lays out for, which can change
      // whether AppKit hides it, so the two would alternate
      ComposeUI.assert(!newValue, "ComposeView doesn't support auto-hiding scrollers")
      super.autohidesScrollers = false
    }
  }

  /// Always `false`, since `ComposeView` doesn't support rulers.
  ///
  /// Setting it to `true` asserts and keeps it `false`.
  override public final var rulersVisible: Bool {
    get {
      super.rulersVisible
    }
    set {
      // AppKit makes room for rulers in the insets it scrolls with, which the scroll bar decision doesn't count, so content
      // overflowing only beside a ruler would get no scroll bar
      ComposeUI.assert(!newValue, "ComposeView doesn't support rulers")
    }
  }

  /// Always `false`, since `ComposeView` doesn't support the find bar.
  ///
  /// Setting it to `true` asserts and keeps it `false`.
  override public final var isFindBarVisible: Bool {
    get {
      super.isFindBarVisible
    }
    set {
      // AppKit makes room for the find bar in the insets it scrolls with, which the scroll bar decision doesn't count, so
      // content overflowing only below the find bar would get no scroll bar
      ComposeUI.assert(!newValue, "ComposeView doesn't support the find bar")
    }
  }

  #endif

  // MARK: - Render

  /// Refreshes and re-renders the content.
  ///
  /// This call will make a new content from the builder block and re-render the content immediately.
  ///
  /// A refresh requested during a render pass, for example from a render handler, is performed after the pass, at the
  /// view's next layout or on the next run loop iteration, whichever comes first. A view nested in the rendering view
  /// renders within that pass instead.
  ///
  /// - Parameter animated: Whether the refresh is animated. A non-animated refresh starts no animation and does not
  ///   stop the in-flight ones. Default value is `true`.
  open func refresh(animated: Bool = true) {
    ComposeUI.assert(Thread.isMainThread, "refresh(animated:) must be called on the main thread")

    guard canStartRenderPass else {
      setNeedsRefresh(animated: animated)
      return
    }

    // explicit render request, should either consume the prepared content or make a new content
    let preparedContent = self.preparedContent
    self.preparedContent = nil

    let contentNode = preparedContent?.node ?? LayoutCacheNode(node: _makeContent())
    let contentEvaluation = preparedContent?.evaluation ?? ContentEvaluation()
    self.contentNode = contentNode
    self.contentEvaluation = contentEvaluation

    contentUpdateContext = ContentUpdateContext(
      contentNode: contentNode,
      contentEvaluation: contentEvaluation,
      updateType: .refresh(isAnimated: animated),
      previousRenderBounds: lastRenderBounds,
      bounds: CGRect(origin: contentOffset, size: bounds.size),
      preparedAnimationDecision: preparedContent?.animationDecision ?? .all
    )

    // cancel the pending refresh if there is any to avoid double rendering
    // this can happen if `setNeedsRefresh(animated:)` is called then `refresh(animated:)` is called immediately
    if pendingRefresh != nil {
      pendingRefresh = nil
    }

    render()
  }

  private struct PendingRefresh {
    let isAnimated: Bool
  }

  private var pendingRefresh: PendingRefresh?

  /// Requests a refresh of the content.
  ///
  /// This method is non-blocking and will return immediately.
  /// The refresh will be performed at the view's next layout or on the next run loop iteration, whichever comes first.
  ///
  /// Requests made before the refresh is performed are merged into a single refresh. The merged refresh is non-animated
  /// if any request was non-animated. To bypass the merging, call `refresh(animated:)` directly, which cancels any
  /// pending request and refreshes with its own animation flag.
  ///
  /// - Parameter animated: Whether the refresh is animated, see `refresh(animated:)`. Default value is `true`.
  open func setNeedsRefresh(animated: Bool = true) {
    ComposeUI.assert(Thread.isMainThread, "setNeedsRefresh(animated:) must be called on the main thread")

    if pendingRefresh == nil {
      RunLoop.main.perform(inModes: [.common]) { [weak self] in
        self?.performPendingRefresh()
      }
    }

    // a non-animated request is a correctness requirement (for example, snapping to a new pixel grid on a display
    // scale change), while an animated one is a preference, so a pending non-animated request is never upgraded
    // to animated by a later request
    pendingRefresh = PendingRefresh(isAnimated: animated && (pendingRefresh?.isAnimated ?? true))
  }

  private func performPendingRefresh() {
    guard let pendingRefresh else {
      return
    }

    self.pendingRefresh = nil
    refresh(animated: pendingRefresh.isAnimated)
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    renderBoundsChangeIfNeeded()
  }

  /// Performs a pending refresh, or renders the content for the current bounds if they changed since the last render.
  ///
  /// A parent's render pass calls this on a nested `ComposeView` it inserted or resized, so the nested content follows
  /// the parent in the same render pass and, like prepared content, never animates more than the parent's animation
  /// decision allows (see `render()`).
  private func renderBoundsChangeIfNeeded() {
    guard !isRendering else {
      // a layout during this view's own render pass has nothing to do: the pass reads the bounds itself, and checks them
      // again when it ends (see `render()`)
      return
    }

    guard canStartRenderPass else {
      // a layout during another view's render pass runs after that pass, on the next run loop iteration like a
      // deferred refresh
      onNextRunLoop { [weak self] in
        self?.renderBoundsChangeIfNeeded()
      }
      return
    }

    guard pendingRefresh == nil else {
      // pending refreshes could be scheduled from window change, for the layout call, just perform the pending refresh
      performPendingRefresh()
      return
    }

    if contentUpdateContext == nil, boundsChangedSinceLastRender() {
      // no pending render request but bounds changed, should re-render the content

      let contentNode = contentNode ?? LayoutCacheNode(node: _makeContent())
      let contentEvaluation = contentEvaluation ?? ContentEvaluation()
      self.contentNode = contentNode
      self.contentEvaluation = contentEvaluation

      contentUpdateContext = ContentUpdateContext(
        contentNode: contentNode,
        contentEvaluation: contentEvaluation,
        updateType: .boundsChange,
        previousRenderBounds: lastRenderBounds,
        bounds: CGRect(origin: contentOffset, size: bounds.size),
        preparedAnimationDecision: .all
      )
    }

    render()
  }

  /// Whether a render pass of this view can start now.
  ///
  /// A pass can start when no pass is in progress. While a pass is in progress, only a view inside the rendering view
  /// can start one, and only once the rendering view has made its animation decision, which caps the nested pass (see
  /// `render()`). This is how a parent's pass renders the nested views it updates.
  ///
  /// Any other request waits, and runs at the view's next layout or on the next run loop iteration, whichever comes
  /// first. That covers the rendering view itself, whose renderables are mid-update, an ancestor, whose pass would
  /// update the rendering view mid-update, and an unrelated view. So a render handler never interrupts the pass that
  /// calls it.
  private var canStartRenderPass: Bool {
    guard !isRendering else {
      return false
    }
    guard let renderingView = ComposeView.renderingView else {
      return true
    }
    return self.isDescendant(of: renderingView) && renderingView.renderingAnimationDecision != nil
  }

  /// Whether a render pass is in progress.
  private var isRendering = false

  /// The theme that the render pass read first, which `theme` returns until the pass ends.
  private var renderPassTheme: Theme?

  /// The theme of the view.
  ///
  /// It stays the same during a render pass, as the theme that the pass read first, so change the theme outside a
  /// render pass: a change made during one renders in the next pass, and a change undone in the same pass can leave
  /// the pass's content in the changed theme.
  override public var theme: Theme {
    // the renderables' updates read the theme from the pass instead of the appearance, which allocates to read on
    // macOS. it's read on the first read instead of when the pass begins, so that a pass without a themed renderable
    // reads nothing, and it's kept on the main thread, where the pass runs
    guard Thread.isMainThread, isRendering else {
      return super.theme
    }

    if let renderPassTheme {
      return renderPassTheme
    }
    let theme = super.theme
    renderPassTheme = theme
    return theme
  }

  /// The override theme of the view.
  ///
  /// Setting it during the view's render pass, such as from a renderable's update, asserts and keeps the current
  /// value, since the theme stays the same during a render pass.
  override public final var overrideTheme: Theme? {
    get {
      super.overrideTheme
    }
    set {
      // a set from another thread waits for the main thread, so it applies after the pass
      if Thread.isMainThread, isRendering {
        ComposeUI.assertFailure("ComposeView doesn't support changing the theme during its render pass")
        return
      }
      super.overrideTheme = newValue
    }
  }

  /// The view whose render pass is in progress. Main thread only.
  ///
  /// Render passes only nest downwards (see `canStartRenderPass`), so this is the innermost rendering view, and
  /// `render()` restores the outer one when a nested render pass ends.
  private static var renderingView: ComposeView?

  /// Performs a render pass.
  open func render() {
    ComposeUI.assert(Thread.isMainThread, "render() must be called on the main thread")

    guard let contentUpdateContext, !isRendering else {
      return
    }

    guard canStartRenderPass else {
      // a render pass that cannot start now keeps its prepared content and runs on the next run loop iteration.
      onNextRunLoop { [weak self] in
        self?.render()
      }
      return
    }

    let outerRenderingView = ComposeView.renderingView
    let animationDecisionCap = contentUpdateContext.preparedAnimationDecision
      .capped(by: outerRenderingView?.renderingAnimationDecision ?? .all)

    isRendering = true
    ComposeView.renderingView = self

    CATransaction.disableAnimations { // disable all implicit animations to have a clean environment for rendering
      render(contentUpdateContext, animationDecisionCap: animationDecisionCap)
    }

    self.contentUpdateContext = nil
    renderingAnimationDecision = nil
    renderPassTheme = nil

    ComposeView.renderingView = outerRenderingView
    isRendering = false

    // a render handler or a renderable lifecycle block can change the bounds after the pass read them, so render the
    // current bounds after the pass if they differ
    if boundsChangedSinceLastRender() {
      onNextRunLoop { [weak self] in
        self?.renderBoundsChangeIfNeeded()
      }
    }
  }

  /// Performs the render pass for a content update.
  ///
  /// - Parameters:
  ///   - context: The content update to render.
  ///   - animationDecisionCap: The animation decision cap this render pass can run.
  private func render(_ context: ContentUpdateContext, animationDecisionCap: AnimationDecision) {
    let contentNode = context.contentNode
    let contentEvaluation = context.contentEvaluation

    #if DEBUG
    debug?.onEvent(.renderWillBegin(contentNode: contentNode))
    #endif

    let oldShowsHorizontalScrollIndicator = showsHorizontalScrollIndicator
    let oldShowsVerticalScrollIndicator = showsVerticalScrollIndicator

    // perform the layout
    let layoutResult = layout(context)
    let renderSize = layoutResult.renderSize
    let insets = layoutResult.insets
    var renderBounds = CGRect(origin: context.bounds.origin, size: renderSize)
    var contentSize = contentNode.size

    let sizeBetweenInsets = Self.sizeBetweenInsets(insets, in: renderSize)

    // the layout and the render bounds compute their sizes with different arithmetic, so content that fits the render
    // bounds exactly can differ from them by floating-point noise. compare them with `extends(beyond:)` instead of `<`
    // and `>`, so the noise doesn't center, scroll, clip, or show scroll indicators.
    var centeredChildFrame: CGRect?
    if sizeBetweenInsets.width.extends(beyond: contentSize.width) || sizeBetweenInsets.height.extends(beyond: contentSize.height) {
      // if content is smaller than the container in either dimension, should center the content in it

      let adjustedContentSize = CGSize(
        width: max(contentSize.width, sizeBetweenInsets.width),
        height: max(contentSize.height, sizeBetweenInsets.height)
      )

      // logic copied from FrameNode.render(visibleBounds:into:) (part 1)
      centeredChildFrame = Layout.position(rect: contentSize, in: adjustedContentSize, alignment: .center)
      contentSize = adjustedContentSize
    }

    let overflowsHorizontally = contentSize.width.extends(beyond: sizeBetweenInsets.width)
    let overflowsVertically = contentSize.height.extends(beyond: sizeBetweenInsets.height)

    // round the content size up to whole pixels. along an axis the content fits, use the container size instead, since
    // the content can exceed it by floating-point noise, and rounding that up would add a pixel to scroll.
    var roundedContentSize = contentSize.roundedUp(scaleFactor: contentScaleFactor)
    if !overflowsHorizontally {
      roundedContentSize.width = sizeBetweenInsets.width
    }
    if !overflowsVertically {
      roundedContentSize.height = sizeBetweenInsets.height
    }

    #if canImport(AppKit)
    if self.contentSize != roundedContentSize || renderSize != context.previousRenderBounds?.size {
      invalidateScrollElasticity()
    }
    #endif

    // set content size
    self.contentSize = roundedContentSize

    #if canImport(AppKit)
    if layoutResult.needsContentOffsetClamp {
      // the layout kept the offset across its scroll bar changes. clamp it now, against the final content size and
      // visible area, as AppKit clamps it.
      setContentOffsetExactly(
        contentView.constrainBoundsRect(CGRect(origin: contentOffset, size: contentView.bounds.size)).origin
      )
    }
    #endif

    // update scrollable behavior
    switch scrollBehavior {
    case .auto:
      isScrollEnabled = overflowsHorizontally || overflowsVertically
      alwaysBounceHorizontal = false
      alwaysBounceVertical = false
    case .manual:
      break
    case .always:
      isScrollEnabled = true
      alwaysBounceHorizontal = true
      alwaysBounceVertical = true
    case .never:
      isScrollEnabled = false
      alwaysBounceHorizontal = false
      alwaysBounceVertical = false
    }

    #if DEBUG
    debug?.onEvent(.renderDidUpdateScrollableBehavior(isScrollEnabled: isScrollEnabled, alwaysBounceHorizontal: alwaysBounceHorizontal, alwaysBounceVertical: alwaysBounceVertical))
    #endif

    switch clippingBehavior {
    case .auto:
      clipsToBounds = isScrollEnabled
    case .manual:
      break
    case .always:
      clipsToBounds = true
    case .never:
      clipsToBounds = false
    }

    #if DEBUG
    debug?.onEvent(.renderDidUpdateClippingBehavior(clipsToBounds: clipsToBounds))
    #endif

    // flash a scroll indicator the layout showed, now that the content size is set, so the flash shows the new range
    if (oldShowsHorizontalScrollIndicator == false && showsHorizontalScrollIndicator == true) ||
      (oldShowsVerticalScrollIndicator == false && showsVerticalScrollIndicator == true)
    {
      flashScrollIndicators()
    }

    #if DEBUG
    debug?.onEvent(.renderDidUpdateScrollIndicatorBehavior(showsHorizontalScrollIndicator: showsHorizontalScrollIndicator, showsVerticalScrollIndicator: showsVerticalScrollIndicator))
    #endif

    // adjust content offset

    // updating the content size or the scroll indicators can move the scroll offset: on AppKit, hiding a legacy
    // scroller grows the clip view, which can clamp the offset. so read the offset after both, to render the viewport
    // the view ends up with.
    renderBounds.origin = contentOffset

    if let willRenderHandler {
      willRenderHandler(self, WillRenderContext(contentSize: roundedContentSize, renderBounds: renderBounds, renderType: context.renderType(bounds: renderBounds)))

      // the will-render handler may change the bounds, so read the content offset again.
      // ignoring the size change because the layout above already used the old size. if the size changes, the render
      // pass will be triggered again after the pass ends (see `render()`).
      renderBounds.origin = contentOffset
    }

    // the render bounds are final from here on, so the render type and the animation decision are made once per pass.
    // a pass within a parent's render pass is capped by the parent's animation decision: the view's animation behavior
    // can lower it but never raise it. the view's own updates carry `.all`, which caps nothing. nested views rendering
    // within this pass inherit the animation decision in turn, so a cap reaches every depth.
    let renderType = context.renderType(bounds: renderBounds)
    let animationDecision = animationBehavior
      .animationDecision(renderType: renderType, contentView: self)
      .capped(by: animationDecisionCap)

    renderingAnimationDecision = animationDecision

    let visibleBounds = renderBounds.inset(by: visibleBoundsInsets)

    // get renderable items

    // the nodes append their items to one array, made at the previous pass's item count, which is usually this pass's
    var newRenderableItems: [RenderableItem] = []
    newRenderableItems.reserveCapacity(renderableItemIds.count)
    if let centeredChildFrame {
      // logic copied from FrameNode.render(visibleBounds:into:) (part 2)
      let boundsInChild = visibleBounds.translate(-centeredChildFrame.origin)

      #if DEBUG
      debug?.onEvent(.renderWillRequestRenderableItems(visibleBounds: boundsInChild))
      #endif

      contentNode.render(visibleBounds: boundsInChild, into: &newRenderableItems)
      for index in newRenderableItems.indices {
        newRenderableItems[index].frame = newRenderableItems[index].frame.translate(centeredChildFrame.origin)
      }
    } else {
      #if DEBUG
      debug?.onEvent(.renderWillRequestRenderableItems(visibleBounds: visibleBounds))
      #endif

      contentNode.render(visibleBounds: visibleBounds, into: &newRenderableItems)
    }

    // prefetched before the renderables update, so that the work that the items start on other threads goes on while
    // the pass does
    prefetch(
      visibleItems: newRenderableItems,
      visibleBounds: visibleBounds,
      contentOrigin: centeredChildFrame?.origin ?? .zero,
      horizontally: overflowsHorizontally,
      vertically: overflowsVertically,
      contentNode: contentNode
    )

    #if DEBUG
    debug?.onEvent(.renderDidReceiveRenderableItems(renderableItems: newRenderableItems, contentSize: contentSize))
    #endif

    // set up the renderable item ids and map
    let oldRenderableItems = renderableItems
    let oldRenderableItemIds = renderableItemIds
    var oldRenderableMap = renderableMap

    #if COMPOSEUI_SANITY_CHECKS
    // sanity check for old renderable item ids and maps before rendering
    let oldRenderableItemIndexMap = renderableItemIndexMap
    ComposeUI.assert(oldRenderableItems.count == oldRenderableItemIds.count, "mismatched old renderable item and id counts")
    ComposeUI.assert(oldRenderableItemIds.count == oldRenderableItemIndexMap.count, "mismatched old renderable item count")
    ComposeUI.assert(oldRenderableItemIds.count == oldRenderableMap.count, "mismatched old renderable count")
    for (index, id) in oldRenderableItemIds.enumerated() {
      ComposeUI.assert(oldRenderableItemIndexMap[id] == index, "mismatched old renderable item index: \(id.id)")
      ComposeUI.assert(oldRenderableMap[id] != nil, "missing old renderable: \(id.id)")
    }
    #endif

    let newRenderableItemsCount = newRenderableItems.count
    renderableItemIds = []
    renderableItemIds.reserveCapacity(newRenderableItemsCount)
    renderableItemIndexMap = [:]
    renderableItemIndexMap.reserveCapacity(newRenderableItemsCount)
    renderableMap = [:]
    renderableMap.reserveCapacity(newRenderableItemsCount)

    for index in newRenderableItems.indices {
      let id = newRenderableItems[index].id
      renderableItemIds.append(id)
      #if DEBUG
      // the insert returns the index of an earlier item of the id, so the check for a conflict takes no lookup of its own
      if renderableItemIndexMap.updateValue(index, forKey: id) != nil {
        ComposeUI.assertFailure("conflicting renderable item id: \(id.id)")
      }
      #else
      renderableItemIndexMap[id] = index
      #endif
    }
    renderableItems = newRenderableItems

    // update the renderables

    // the ids of the items whose renderable type changed, so their renderables are replaced
    var replacedIds: Set<ComposeNodeId> = []

    // the z-order bookkeeping, which records the reused items below
    var zOrder = ZOrderPass(oldItemCount: oldRenderableItemIds.count, previousKeyOffset: zPositionKeyOffset)

    // the removals below can keep their reusable views in place, for the insertions after them
    inPlaceReuse.startKeeping(hasPool: renderablePool != nil)

    // the old and new items are read in place from their arrays, by index, since looking them up in a map of items
    // would copy each item, which retains and releases its references
    for oldIndex in oldRenderableItemIds.indices {
      let oldId = oldRenderableItemIds[oldIndex]

      let isReplaced: Bool
      if let newIndex = renderableItemIndexMap[oldId] {
        if oldRenderableItems[oldIndex].hasSameRenderableType(as: newRenderableItems[newIndex]) {
          // this renderable item is still in the content, plan to reuse it
          zOrder.recordReuse(oldIndex: oldIndex, newIndex: newIndex)
          continue
        } else {
          // an item can only update a renderable of its own type, so when its type changed, the old renderable is
          // removed and a new one is inserted, both without transitions, since the item stays in the content
          isReplaced = true
          replacedIds.insert(oldId)
        }
      } else {
        isReplaced = false
      }

      // [1/3] 🗑️ remove the renderable item that is no longer in the content, or whose renderable type changed

      // the renderable may still have an in-flight insert transition. cancel its pending completion so a late
      // `didInsert` is not called for a renderable that is being removed (it may even be pooled and serving a
      // different item by the time the insert transition completes).
      insertingRenderableTransitionCompletionMap[oldId]?.cancel()

      if let oldRenderable = oldRenderableMap[oldId] {
        let oldRenderableItem = oldRenderableItems[oldIndex]
        let oldFrame = oldRenderable.frame
        oldRenderableItem.performWillRemove(oldRenderable, RenderableRemoveContext(oldFrame: oldFrame, contentView: self))

        let removeTransition = !isReplaced && animationDecision.allowsTransitions ? oldRenderableItem.transition?.remove : nil

        // the view is an argument instead of a capture, since a removal transition keeps this block until it completes,
        // and mustn't keep the view alive, as an insert transition doesn't
        let removeBlock = { (contentView: ComposeView) in
          // the reuse is decided before the item's callbacks, so that they can't change it midway. a reusable view that
          // can stay in place does, for an insertion of its kind in the pass, see `InPlaceReuse`
          let reuseKey = oldRenderableItem.reuseKey
          let renderablePool = reuseKey == nil ? nil : contentView.renderablePool
          let keepsInPlace: Bool
          if let reuseKey, renderablePool != nil {
            keepsInPlace = contentView.inPlaceReuse.canKeep(oldRenderable, key: reuseKey)
          } else {
            keepsInPlace = false
          }
          if !keepsInPlace {
            oldRenderable.removeFromParent()
          }
          oldRenderableItem.performDidRemove(oldRenderable, RenderableRemoveContext(oldFrame: oldFrame, contentView: contentView))

          // if the item opts into reuse, reset the renderable so that a future insertion of the same kind can reuse it
          // instead of creating a new renderable.
          // the cancel path (re-insertion during a remove transition) does not run this block, so a revived renderable is never pooled.
          if let reuseKey, let renderablePool {
            removeTransition?.resetForReuse(renderable: oldRenderable)
            oldRenderableItem.performResetForReuse(oldRenderable)

            // a renderable may have in-flight animations, must clear them here to avoid leaking into the next reuse.
            // animations in sublayers should be cleared by the node's `resetForReuse` block.
            oldRenderable.layer.removeAllAnimations()

            // the render pass owns the renderable layer's `zPosition` (see `ZOrderPass.updateZPosition(of:zIndex:index:)`),
            // reset it so the pooled renderable is freshly-made-equivalent.
            if oldRenderable.layer.zPosition != 0 {
              oldRenderable.layer.disableActions(for: "zPosition") {
                oldRenderable.layer.zPosition = 0
              }
            }

            if keepsInPlace {
              contentView.inPlaceReuse.keep(oldRenderable, key: reuseKey)
            } else {
              renderablePool.enqueue(oldRenderable, key: reuseKey)
            }
          }
        }

        if let removeTransition {
          let removingKey = RemovingRenderableKey(id: oldId, renderableType: oldRenderableItem.renderableType)
          let completion = CancellableBlock { [weak self] in
            ComposeUI.assert(Thread.isMainThread, "remove transition completion must be called on the main thread")
            // the view can be released before its removal transition completes, which leaves no removal to finish
            guard let self else {
              return
            }

            self.removingRenderableMap.removeValue(forKey: removingKey)

            removeBlock(self)

            #if DEBUG
            debug?.onEvent(.renderDidRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
            #endif

          } cancel: { [weak self] in
            self?.removingRenderableMap.removeValue(forKey: removingKey)

            #if DEBUG
            self?.debug?.onEvent(.renderDidCancelRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
            #endif
          }

          // if there's a remove transition, it can take time to complete, we need to track the old renderable until
          // the transition is completed because the renderable may be re-inserted into the renderable hierarchy later
          removingRenderableMap[removingKey] = RemovingRenderable(
            renderable: oldRenderable,
            removeTransition: removeTransition,
            completion: completion,
            zIndex: oldRenderableItem.zIndex,
            zPositionKey: zOrder.previousKey(at: oldIndex)
          )

          #if DEBUG
          debug?.onEvent(.renderWillRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
          #endif

          removeTransition.animate(
            renderable: oldRenderable,
            context: RenderableTransition.RemoveTransition.Context(contentView: self),
            completion: completion.execute
          )
        } else {
          #if DEBUG
          debug?.onEvent(.renderWillRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
          #endif

          removeBlock(self)

          #if DEBUG
          debug?.onEvent(.renderDidRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
          #endif
        }
      } else {
        ComposeUI.assertFailure("old renderable item or old renderable not found: \(oldId.id)")
      }

      if isReplaced {
        // the update pass inserts a renderable of the new type instead of reusing the old one
        oldRenderableMap[oldId] = nil
      }
    }

    zOrder.finishRecording(itemCount: newRenderableItemsCount)
    zPositionKeyOffset = zOrder.keyOffset
    zOrder.moveKeys(ofRemovingRenderables: &removingRenderableMap)

    for (itemIndex, renderableItem) in newRenderableItems.enumerated() {
      let id = renderableItem.id

      let renderable: Renderable
      if let reusedRenderable = oldRenderableMap[id] {
        // [2/3] ♻️ reuse the renderable item that is still in the content
        renderable = reusedRenderable

        #if DEBUG
        debug?.onEvent(.renderWillReuseRenderable(item: renderableItem, renderable: renderable))
        #endif

        renderable.layer.restoreIdentityTransformIfNeeded()

        let updateType: RenderableUpdateType
        switch context.updateType {
        case .refresh:
          updateType = .refresh
        case .boundsChange:
          updateType = .boundsChange
        }

        let oldFrame = renderable.frame
        let newFrame = renderableItem.frame.rounded(scaleFactor: contentScaleFactor)

        let animationTiming: AnimationTiming?
        if animationDecision.allowsAnimations, let renderableItemAnimationTiming = renderableItem.animationTiming {
          animationTiming = renderableItemAnimationTiming
        } else {
          animationTiming = nil
        }

        let renderableUpdateContext = RenderableUpdateContext(
          updateType: updateType,
          oldFrame: oldFrame,
          newFrame: newFrame,
          previousRenderBounds: context.previousRenderBounds,
          renderBounds: renderBounds,
          animationTiming: animationTiming,
          contentView: self,
          contentEvaluation: contentEvaluation,
          animationDecision: animationDecision
        )

        renderableItem.performWillUpdate(renderable, renderableUpdateContext)

        if zOrder.restacksViews, let view = renderable.view, !ZOrderPass.passesClicksThrough(view) {
          // only the views that take clicks need re-stacking: the subview order drives the hit-testing order.
          // the visual z-order is driven by the layers' `zPosition`, so layer items need no re-stacking.
          // skips `moveToFront()`'s `subviews.last` check, which copies the array, since only the first view of a
          // restack can be at the front already. `addSubview` would walk the view's subviews
          view.superview?.bringSubviewToFront(view)
        }

        zOrder.updateZPosition(of: renderable, zIndex: renderableItem.zIndex, index: itemIndex)

        renderable.updateFrame(newFrame, animationTiming: animationTiming)

        renderableItem.performUpdate(renderable, renderableUpdateContext)

        // a nested `ComposeView` this pass resized renders its content for the new size within this render pass,
        // instead of on its own later, so its animations are capped by this pass's animation decision
        if oldFrame.size != newFrame.size {
          (renderable.view as? ComposeView)?.renderBoundsChangeIfNeeded()
        }

        #if DEBUG
        debug?.onEvent(.renderDidReuseRenderable(item: renderableItem, renderable: renderable))
        #endif

      } else {
        // [3/3] 🆕 insert the renderable item that is new
        let newFrame = renderableItem.frame.rounded(scaleFactor: contentScaleFactor)

        // the insert transition that will animate this insertion, if any. a renderable that replaces one of another type
        // isn't animated in, since its item stays in the content.
        let insertTransition = animationDecision.allowsTransitions && !replacedIds.contains(id) ? renderableItem.transition?.insert : nil

        // the root-layer model position and transform the removal left behind, captured before this pass applies the
        // target frame and resets the transform to identity, so a taking-over insert transition can anchor its
        // animation to the removal's live state.
        var revivalPosition: CGPoint?
        var revivalTransform: CATransform3D?

        if let removingRenderable = removingRenderableMap[RemovingRenderableKey(id: id, renderableType: renderableItem.renderableType)] {
          // found a matching removing renderable, should add it back to the renderable hierarchy.
          // cancelling the completion cancels the removal and clears it from `removingRenderableMap`.
          removingRenderable.completion.cancel()

          // the cancelled removal's residue is undone by whoever takes over the renderable: a taking-over insert
          // transition continues from the live in-flight state, otherwise the remove transition's `resetForReuse`
          // snaps the renderable to its resting state.
          if removingRenderable.removeTransition.isTakenOver(by: insertTransition) {
            revivalPosition = removingRenderable.renderable.layer.position
            revivalTransform = removingRenderable.renderable.layer.transform
            // before the content update, so the content's values land on the prepared ones
            insertTransition?.prepareForTakeover(renderable: removingRenderable.renderable)
          } else {
            removingRenderable.removeTransition.resetForReuse(renderable: removingRenderable.renderable)
          }

          renderable = removingRenderable.renderable
        } else if let reuseKey = renderableItem.reuseKey, let reusableRenderable = inPlaceReuse.take(reuseKey) ?? renderablePool?.dequeue(reuseKey) {
          // reuse a renderable of the same kind instead of creating a new one: a view that a removal in this pass left
          // in place, or a pooled one
          renderable = reusableRenderable
        } else {
          renderable = renderableItem.makeRenderable(RenderableMakeContext(initialFrame: newFrame, contentView: self))
        }

        #if DEBUG
        debug?.onEvent(.renderWillInsertRenderable(item: renderableItem, renderable: renderable))
        #endif

        renderable.layer.restoreIdentityTransformIfNeeded()

        let frameBeforeWillInsert = renderable.frame
        renderableItem.performWillInsert(renderable, RenderableInsertContext(oldFrame: frameBeforeWillInsert, newFrame: newFrame, contentView: self))
        let frameAfterWillInsert = renderable.frame

        let renderableUpdateContext = RenderableUpdateContext(
          updateType: .insert,
          oldFrame: frameAfterWillInsert,
          newFrame: newFrame,
          previousRenderBounds: context.previousRenderBounds,
          renderBounds: renderBounds,
          animationTiming: nil, // no animation for insertion
          contentView: self,
          contentEvaluation: contentEvaluation,
          animationDecision: animationDecision
        )

        renderableItem.performWillUpdate(renderable, renderableUpdateContext)

        zOrder.insert(renderable, at: itemIndex, into: contentContainerView, ids: renderableItemIds, reusedRenderables: oldRenderableMap)
        renderable.assertIdentityTransform()
        renderable.setFrame(newFrame)

        zOrder.updateZPosition(of: renderable, zIndex: renderableItem.zIndex, index: itemIndex)

        renderableItem.performUpdate(renderable, renderableUpdateContext)

        // a nested `ComposeView` this pass inserted renders now, within this pass, for the same reasons as a resized one
        (renderable.view as? ComposeView)?.renderBoundsChangeIfNeeded()

        let renderableInsertContext = RenderableInsertContext(oldFrame: frameAfterWillInsert, newFrame: newFrame, contentView: self)
        if let insertTransition {
          // has insert transition, animate the renderable insertion

          // the completion is tracked as a cancellable block so that removing the renderable while the transition is
          // still in flight can cancel the pending `didInsert`.
          // a previous completion for the same id, if any, was already cancelled by the removal that preceded this re-insertion.
          let completion = CancellableBlock { [weak self] in
            ComposeUI.assert(Thread.isMainThread, "insert transition completion must be called on the main thread")
            self?.insertingRenderableTransitionCompletionMap.removeValue(forKey: id)

            // at the moment, the renderable's frame may not be the target frame, this is because during the insert transition,
            // the renderable can be refreshed, and the renderable's frame may be updated to a different frame.
            //
            // insert: [-------------------] setting frame to frame1
            // reuse:        [-----]         during the insert transition, the renderable's frame is updated to frame2
            renderableItem.performDidInsert(renderable, renderableInsertContext)

            #if DEBUG
            self?.debug?.onEvent(.renderDidInsertRenderable(item: renderableItem, renderable: renderable))
            #endif
          } cancel: { [weak self] in
            self?.insertingRenderableTransitionCompletionMap.removeValue(forKey: id)
          }

          insertingRenderableTransitionCompletionMap[id] = completion

          insertTransition.animate(
            renderable: renderable,
            context: RenderableTransition.InsertTransition.Context(targetFrame: newFrame, revivalPosition: revivalPosition, revivalTransform: revivalTransform, contentView: self),
            completion: completion.execute
          )
        } else {
          // no insert transition, just call did insert
          renderableItem.performDidInsert(renderable, renderableInsertContext)

          #if DEBUG
          debug?.onEvent(.renderDidInsertRenderable(item: renderableItem, renderable: renderable))
          #endif
        }
      }

      renderableMap[id] = renderable
    }

    // the pass stops keeping views, so that a removal that finishes later leaves at once, and the views that the removals
    // left in place and no insertion took leave now, for the pool
    inPlaceReuse.stopKeeping(addingTo: renderablePool)

    #if COMPOSEUI_SANITY_CHECKS
    // sanity check for renderable item ids and maps after rendering
    ComposeUI.assert(renderableItemIds.count == renderableItemIndexMap.count, "mismatched renderable item count")
    ComposeUI.assert(renderableItemIds.count == renderableMap.count, "mismatched renderable count")
    for id in renderableItemIds {
      ComposeUI.assert(renderableItemIndexMap[id] != nil, "missing renderable item: \(id.id)")
      ComposeUI.assert(renderableMap[id] != nil, "missing renderable: \(id.id)")
    }
    #endif

    if let didRenderHandler {
      didRenderHandler(self, DidRenderContext(contentSize: contentSize, renderBounds: renderBounds, renderType: renderType))
    }

    #if DEBUG
    debug?.onEvent(.renderDidFinish(renderableItemIds: renderableItemIds, renderableItemMap: makeRenderableItemMap(), renderableMap: renderableMap))
    #endif

    lastRenderBounds = renderBounds
    lastBoundsSize = context.bounds.size
    lastRenderInsets = insets
  }

  /// Performs the layout for a content update, which also updates the scroll indicators.
  ///
  /// - Parameter context: The content update being rendered.
  /// - Returns: The render size the content laid out in, the content insets it laid out between, and whether the offset
  ///   needs a clamp once the content size is set, since the layout changed the scroll bars and undid the clamp AppKit
  ///   applied for them.
  private func layout(_ context: ContentUpdateContext) -> (renderSize: CGSize, insets: EdgeInsets, needsContentOffsetClamp: Bool) {
    let contentNode = context.contentNode
    let boundsSize = context.bounds.size

    // read the insets once, so a handler that changes them can't mix two values in the pass, and the next pass renders the
    // change. the insets in effect also count legacy scroll bars over the content, so a change shows in the insets without
    // them.
    let startInsets = adjustedContentInset
    let startInsetsExcludingScrollBars = contentInsetExcludingScrollBars

    // hiding a legacy scroll bar grows the visible area, and AppKit clamps the offset to it, against the old content
    // size and even when the update shows the scroll bar again. keep the offset instead, and clamp it once the final
    // content size is set (see `render(_:)`).
    let oldScrollIndicators = (showsHorizontalScrollIndicator, showsVerticalScrollIndicator)
    var didKeepContentOffset = false
    func keepingContentOffset(_ change: () -> Void) {
      let contentOffset = self.contentOffset
      change()
      if self.contentOffset != contentOffset {
        setContentOffsetExactly(contentOffset)
        didKeepContentOffset = true
      }
    }
    func setScrollIndicators(horizontal: Bool, vertical: Bool) {
      keepingContentOffset {
        showsHorizontalScrollIndicator = horizontal
        showsVerticalScrollIndicator = vertical
      }
    }

    var laidOutContainerSize: CGSize?
    var laidOutSize: CGSize?
    func layout(for containerSize: CGSize, sizeBetweenInsets: CGSize) {
      let layoutSize = CGSize(width: max(sizeBetweenInsets.width, 0), height: max(sizeBetweenInsets.height, 0))
      // the handler hears of each new viewport, even one with the same layout size, since it can adjust the layout to it
      guard containerSize != laidOutContainerSize || layoutSize != laidOutSize else {
        return
      }

      // report the current offset, not the one the update was made with, since a will-layout handler can move it between
      // the layouts of a pass, and a held update can run after the view scrolled.
      let bounds = CGRect(origin: contentOffset, size: containerSize)
      if let willLayoutHandler {
        let scrollSettings = (scrollBehavior, scrollIndicatorBehavior, clippingBehavior)
        let scrollIndicators = (horizontal: showsHorizontalScrollIndicator, vertical: showsVerticalScrollIndicator)
        #if canImport(AppKit)
        let scrollerStyle = self.scrollerStyle
        #endif
        let renderSize = self.renderSize(for: boundsSize)

        willLayoutHandler(self, WillLayoutContext(containerSize: layoutSize, renderType: context.renderType(bounds: bounds)))

        // the handler can't change the scroll settings or the visible size
        if (scrollBehavior, scrollIndicatorBehavior, clippingBehavior) != scrollSettings {
          ComposeUI.assertFailure("onWillLayout can't change scrollBehavior, scrollIndicatorBehavior or clippingBehavior")
          (scrollBehavior, scrollIndicatorBehavior, clippingBehavior) = scrollSettings
        }
        if self.renderSize(for: boundsSize) != renderSize {
          ComposeUI.assertFailure("onWillLayout can't change the visible size")
          keepingContentOffset {
            #if canImport(AppKit)
            self.scrollerStyle = scrollerStyle
            #endif
            showsHorizontalScrollIndicator = scrollIndicators.horizontal
            showsVerticalScrollIndicator = scrollIndicators.vertical
          }
        }
      }

      #if DEBUG
      debug?.onEvent(.renderWillLayout(contentNode: contentNode, bounds: bounds, visibleBounds: bounds.inset(by: visibleBoundsInsets)))
      #endif

      // made after the handler, which can change the scale
      let layoutContext = ComposeNodeLayoutContext(scaleFactor: contentScaleFactor, contentEvaluation: context.contentEvaluation)
      _ = contentNode.layout(containerSize: layoutSize, context: layoutContext)
      laidOutContainerSize = containerSize
      laidOutSize = layoutSize

      #if DEBUG
      debug?.onEvent(.renderDidLayout(contentSize: contentNode.size))
      #endif
    }

    switch scrollIndicatorBehavior {
    case .auto:
      let keepsScrollIndicators: Bool
      switch context.updateType {
      case .refresh:
        keepsScrollIndicators = false
      case .boundsChange:
        // a scroll changes neither the content, the view's size, the render size nor the insets, so it keeps the scroll
        // indicators, if the last update also decided them automatically. the content then lays out once, for the size
        // the cached layout already has.
        let isScroll = boundsSize == lastBoundsSize &&
          context.previousRenderBounds?.size == self.renderSize(for: boundsSize) &&
          lastRenderInsets?.isEqual(to: adjustedContentInset) == true
        keepsScrollIndicators = isScroll && lastScrollIndicatorBehavior == .auto
      }

      if !keepsScrollIndicators {
        // the space between the insets AppKit leaves now, plus the space the scroll bars that show take from the visible
        // size or the insets, is the space without scroll bars. it counts what else AppKit changes, such as the insets it
        // scrolls with when they're taller than the view.
        let shownScrollBarSpace = scrollBarSpace(horizontal: showsHorizontalScrollIndicator, vertical: showsVerticalScrollIndicator, in: bounds.size)
        let sizeBetweenInsetsNow = Self.sizeBetweenInsets(startInsets, in: self.renderSize(for: boundsSize))
        let sizeWithoutScrollBars = CGSize(width: sizeBetweenInsetsNow.width + shownScrollBarSpace.width, height: sizeBetweenInsetsNow.height + shownScrollBarSpace.height)

        // the content or its container size changed, so lay out for the view's full size to check whether the scroll
        // indicators need to change.
        layout(for: boundsSize, sizeBetweenInsets: sizeWithoutScrollBars)
        var horizontal = contentNode.size.width.extends(beyond: sizeWithoutScrollBars.width)
        var vertical = contentNode.size.height.extends(beyond: sizeWithoutScrollBars.height)

        // a legacy scroll bar takes space, which can make the content overflow the other axis. compute that space rather
        // than set the scroll bars and read AppKit's tiling, which re-tiles twice when the pass hides a scroll bar and
        // shows it again.
        let space = scrollBarSpace(horizontal: horizontal, vertical: vertical, in: boundsSize)
        if space != .zero {
          let sizeBetweenInsets = sizeWithoutScrollBars - space
          layout(for: boundsSize - space, sizeBetweenInsets: sizeBetweenInsets)
          horizontal = horizontal || contentNode.size.width.extends(beyond: sizeBetweenInsets.width)
          vertical = vertical || contentNode.size.height.extends(beyond: sizeBetweenInsets.height)
        }
        setScrollIndicators(horizontal: horizontal, vertical: vertical)
      }
    case .manual:
      break
    case .always:
      setScrollIndicators(horizontal: true, vertical: true)
    case .never:
      setScrollIndicators(horizontal: false, vertical: false)
    }
    lastScrollIndicatorBehavior = scrollIndicatorBehavior

    // the insets in effect once the scroll bars are set, unless a handler changed the insets in this pass, which changed
    // the insets in effect too. keep the ones the pass began with then, and the next pass renders the change.
    let insets = contentInsetExcludingScrollBars.isEqual(to: startInsetsExcludingScrollBars) ? adjustedContentInset : startInsets
    let renderSize = self.renderSize(for: boundsSize)
    layout(for: renderSize, sizeBetweenInsets: Self.sizeBetweenInsets(insets, in: renderSize))

    // if the scroll bars end as they started, the visible area hasn't changed, so the offset needs no clamp, and AppKit
    // clamps it itself for a content size change. clamping anyway would move an offset set outside the scrollable range,
    // which the view keeps otherwise.
    let needsContentOffsetClamp = didKeepContentOffset && (showsHorizontalScrollIndicator, showsVerticalScrollIndicator) != oldScrollIndicators
    return (renderSize, insets, needsContentOffsetClamp)
  }

  /// The content insets without the thickness that macOS adds to `adjustedContentInset` for legacy scroll bars over the
  /// content.
  private var contentInsetExcludingScrollBars: EdgeInsets {
    #if canImport(AppKit)
    contentInset
    #else
    adjustedContentInset
    #endif
  }

  /// Returns the space that the scroll bars take from the view when they show.
  ///
  /// - Parameters:
  ///   - horizontal: Whether the horizontal scroll bar shows.
  ///   - vertical: Whether the vertical scroll bar shows.
  ///   - boundsSize: The size of the view.
  /// - Returns: The width the vertical scroll bar takes, and the height the horizontal one takes.
  private func scrollBarSpace(horizontal: Bool, vertical: Bool, in boundsSize: CGSize) -> CGSize {
    #if canImport(AppKit)
    guard scrollerStyle == .legacy else {
      return .zero
    }

    // AppKit sizes a scroll bar by its scroller's class, which a subclass can override, and as a regular `NSScroller`
    // when it has no scroller. it leaves a view no thicker than the scroll bar whole, with the scroll bar partly outside.
    func space(of scroller: NSScroller?, along length: CGFloat) -> CGFloat {
      let thickness = scroller.map { type(of: $0).scrollerWidth(for: $0.controlSize, scrollerStyle: .legacy) }
        ?? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
      return length > thickness ? thickness : 0
    }
    return CGSize(
      width: vertical ? space(of: verticalScroller, along: boundsSize.width) : 0,
      height: horizontal ? space(of: horizontalScroller, along: boundsSize.height) : 0
    )
    #else
    return .zero
    #endif
  }

  /// Returns the size between the insets in a container, which the content lays out in, and centers in if it fits.
  ///
  /// - Parameters:
  ///   - insets: The content insets.
  ///   - containerSize: The size of the container.
  /// - Returns: The container size minus the insets, negative along an axis where the insets exceed the container.
  private static func sizeBetweenInsets(_ insets: EdgeInsets, in containerSize: CGSize) -> CGSize {
    CGSize(width: containerSize.width - insets.left - insets.right, height: containerSize.height - insets.top - insets.bottom)
  }

  /// Returns the size the content lays out and renders for: the bounds size minus the space that legacy scroll bars take
  /// on macOS.
  ///
  /// - Parameter boundsSize: The bounds size the render pass was made for.
  /// - Returns: The render size.
  private func renderSize(for boundsSize: CGSize) -> CGSize {
    let currentBoundsSize = bounds.size
    let visibleSize = self.visibleSize

    if boundsSize == currentBoundsSize {
      // the view hasn't resized since the pass was made, so the visible size is the render size.
      // use it as is rather than the math below, so the render size always matches `renderBounds()`.
      return visibleSize
    } else {
      // the view resized after the pass was made: render for the earlier size, minus the space the scroll bars take now.
      let scrollBarSpace = currentBoundsSize - visibleSize
      let renderSize = boundsSize - scrollBarSpace
      return CGSize(width: max(renderSize.width, 0), height: max(renderSize.height, 0))
    }
  }

  /// Returns the bounds used for layout and rendering.
  private func renderBounds() -> CGRect {
    #if canImport(AppKit)
    // legacy scroll bar shrinks the visible size, so visibleSize could be smaller than the bounds.size
    return CGRect(origin: contentOffset, size: visibleSize)
    #endif

    #if canImport(UIKit)
    return bounds
    #endif
  }

  /// Returns whether the render bounds, the view's size or the content insets changed since the last render pass.
  ///
  /// Before the first render, they count as changed once the view has a size, so the view doesn't render while its size
  /// is still zero.
  private func boundsChangedSinceLastRender() -> Bool {
    // compare the view's size too: with legacy scroll bars on macOS, a resize can leave the render bounds the same while
    // the scroll bars it needs change. and compare the insets, since the content lays out between them.
    renderBounds() != (lastRenderBounds ?? .zero) ||
      bounds.size != (lastBoundsSize ?? .zero) ||
      lastRenderInsets?.isEqual(to: adjustedContentInset) == false
  }

  // MARK: - Prefetching

  /// Whether the view has shown an item that prepares its content ahead of time, before which it doesn't look ahead, so
  /// that content without such items doesn't pay for looking ahead.
  private var showsItemsThatPrefetch = false

  /// The region that the last render pass prefetched, `nil` when the last pass didn't prefetch, or when the view starts
  /// prefetching over, see `restartPrefetching()`.
  private var prefetchedBounds: CGRect?

  /// The items of the part of the content that a render pass prefetches, kept to reuse the array's memory.
  private var prefetchItems: [RenderableItem] = []

  /// The caches that the view's items keep the content that they prepare ahead of time in, by their types.
  private var prefetchCaches: [ObjectIdentifier: AnyObject] = [:]

  /// Returns the cache of a type that the view's items keep the content that they prepare ahead of time in.
  ///
  /// The view releases its caches when it starts prefetching over, see `restartPrefetching()`.
  ///
  /// - Parameter type: The type of the cache.
  /// - Returns: The cache, `nil` until an item makes one.
  func prefetchCache<Cache: AnyObject>(of type: Cache.Type) -> Cache? {
    // the cache is stored under its type's identifier, so it's of the type
    prefetchCaches[ObjectIdentifier(type)].map { unsafeDowncast($0, to: Cache.self) }
  }

  /// Returns the cache of a type that the view's items keep the content that they prepare ahead of time in, made the
  /// first time an item asks for it, see `prefetchCache(of:)`.
  ///
  /// - Parameter make: The block that makes the cache.
  /// - Returns: The cache.
  func prefetchCache<Cache: AnyObject>(make: () -> Cache) -> Cache {
    if let cache = prefetchCache(of: Cache.self) {
      return cache
    } else {
      let cache = make()
      prefetchCaches[ObjectIdentifier(Cache.self)] = cache
      return cache
    }
  }

  /// Releases the prefetch caches, and forgets the prefetched region, so that the next render pass prefetches the whole
  /// region again.
  ///
  /// The items prepare their content for how the view shows it: in its window, at the window's scale, in the window's
  /// color space, and in the view's theme. So the view starts over when any of them changes.
  private func restartPrefetching() {
    prefetchCaches.removeAll()
    prefetchedBounds = nil
  }

  /// Prefetches the items in the part of the region past the visible bounds that the last render pass didn't prefetch,
  /// so that the items about to scroll in prepare their content ahead of time.
  ///
  /// The region extends the visible bounds by their size past each edge along each axis that the content scrolls on.
  /// Each pass prefetches the part of the region that moved since the last pass, a refresh too, instead of the items of
  /// the whole region again, so an item that a refresh changes in the region scrolls in without its content prepared. A
  /// pass without a previous region, or with one that the region doesn't overlap, prefetches the whole region but the
  /// visible bounds, which the pass renders.
  ///
  /// - Parameters:
  ///   - visibleItems: The items in the visible bounds.
  ///   - visibleBounds: The visible bounds.
  ///   - contentOrigin: The origin of the content in the view, which centers content smaller than the view.
  ///   - horizontally: Whether the content scrolls horizontally.
  ///   - vertically: Whether the content scrolls vertically.
  ///   - contentNode: The content node.
  private func prefetch(visibleItems: [RenderableItem], visibleBounds: CGRect, contentOrigin: CGPoint, horizontally: Bool, vertically: Bool, contentNode: LayoutCacheNode) {
    guard horizontally || vertically, window != nil else {
      prefetchedBounds = nil
      return
    }
    if !showsItemsThatPrefetch {
      showsItemsThatPrefetch = visibleItems.contains { $0.prefetchesContent }
    }
    guard showsItemsThatPrefetch else {
      return
    }

    let region = visibleBounds.insetBy(dx: horizontally ? -visibleBounds.width : 0, dy: vertically ? -visibleBounds.height : 0)
    var excludedBounds = visibleBounds
    if let prefetchedBounds, prefetchedBounds.intersects(region) {
      excludedBounds = prefetchedBounds
    }
    prefetchedBounds = region

    let scale = contentScaleFactor
    region.forEachPart(outside: excludedBounds) { part in
      contentNode.render(visibleBounds: part.translate(-contentOrigin), into: &prefetchItems)
      for item in prefetchItems {
        guard let prefetch = item.prefetch else {
          continue
        }
        let frame = item.frame.translate(contentOrigin)
        // an item that reaches into the excluded bounds was prefetched or shown already, and an item in two parts is
        // prefetched by the one with its top left corner in the region
        guard !frame.intersects(excludedBounds), part.contains(CGPoint(x: max(frame.minX, region.minX), y: max(frame.minY, region.minY))) else {
          continue
        }
        prefetch(RenderablePrefetchContext(frame: frame.rounded(scaleFactor: scale), region: region, contentView: self))
      }
      prefetchItems.removeAll(keepingCapacity: true)
    }
  }

  // MARK: - Accessibility

  #if canImport(AppKit)
  /// Returns the content view's accessibility children with the views of the items among them in the items order, in
  /// the places that they take, and the other children, such as views being removed or elements that an app sets, in
  /// theirs.
  ///
  /// AppKit tells a view's children in the subview order, while a render pass keeps only the views that take clicks in
  /// the items order, see `ClickThroughView`.
  ///
  /// - Parameter children: The children that AppKit tells.
  /// - Returns: The children, with the views of the items in the items order.
  func accessibilityChildrenInItemsOrder(_ children: [Any]) -> [Any] {
    var itemIndices: [ObjectIdentifier: Int] = [:]
    for (index, id) in renderableItemIds.enumerated() {
      if let view = renderableMap[id]?.view {
        itemIndices[ObjectIdentifier(view)] = index
      }
    }

    // the places of the items' views among the children, which take the items' views in the items order
    let slots = children.indices.compactMap { place in
      (children[place] as? NSView).flatMap { itemIndices[ObjectIdentifier($0)] }.map { (place: place, itemIndex: $0) }
    }
    let itemViews = slots.sorted { $0.itemIndex < $1.itemIndex }.map { children[$0.place] }
    var orderedChildren = children
    for (slot, view) in zip(slots, itemViews) {
      orderedChildren[slot.place] = view
    }
    return orderedChildren
  }
  #endif

  // MARK: - Testing

  #if DEBUG

  var test: Test { Test(host: self) }

  class Test {

    private let host: ComposeView

    fileprivate init(host: ComposeView) {
      ComposeUI.assert(Thread.isRunningXCTest, "Test namespace should only be used in test target.")
      self.host = host
    }

    var lastRenderBounds: CGRect? {
      host.lastRenderBounds
    }

    var contentUpdateContext: ContentUpdateContext? {
      host.contentUpdateContext
    }

    var removingRenderableMap: [RemovingRenderableKey: RemovingRenderable] {
      host.removingRenderableMap
    }

    var insertingRenderableTransitionCompletionMap: [ComposeNodeId: CancellableBlock] {
      host.insertingRenderableTransitionCompletionMap
    }

    var zPositionStep: CGFloat {
      ZOrderPass.Constants.zPositionStep
    }

    var maxZPositionKey: Int {
      ZOrderPass.Constants.maxKey
    }

    /// The region that the last render pass prefetched.
    var prefetchedBounds: CGRect? {
      host.prefetchedBounds
    }
  }

  #endif
}
