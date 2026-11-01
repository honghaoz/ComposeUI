//
//  ScrollView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/27/24.
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

// MARK: - AppKit

#if canImport(AppKit)
import AppKit

/// A scroll view, like `UIScrollView` in UIKit.
open class ScrollView: NSScrollView {

  override open var wantsUpdateLayer: Bool { true }

  override open var isFlipped: Bool { true }

  override open var contentSize: CGSize {
    get {
      contentContainerView.bounds.size
    }
    set {
      ComposeUI.assert(contentContainerView.frame.origin == .zero)
      contentContainerView.frame = CGRect(origin: .zero, size: newValue)
    }
  }

  /// The offset of the visible area's origin from the content's origin, like `UIScrollView`'s `contentOffset`.
  ///
  /// As on UIKit, setting it rounds the offset to the nearest pixel, and keeps it there, even outside the scrollable range.
  public var contentOffset: CGPoint {
    get {
      contentView.bounds.origin
    }
    set {
      // AppKit places the clip view on whole window pixels, so an offset on whole pixels draws the content on them,
      // while one between pixels blurs it
      let pixelSize = self.pixelSize
      setContentOffsetExactly(
        CGPoint(
          x: (newValue.x / pixelSize.width).rounded() * pixelSize.width,
          y: (newValue.y / pixelSize.height).rounded() * pixelSize.height
        )
      )
    }
  }

  /// The custom distance that the content is inset from the scroll view's edges, like `UIScrollView`'s `contentInset`.
  ///
  /// This is `contentInsets`, which includes the automatic adjustments while `automaticallyAdjustsContentInsets` is on.
  ///
  /// Prefer this over AppKit's `contentInsets` to match UIKit's behavior: setting new insets keeps the content offset,
  /// or clamps it into the new scrollable range if it's outside, while setting `contentInsets` moves the offset by the
  /// change.
  public var contentInset: EdgeInsets {
    get {
      contentInsets
    }
    set {
      // UIKit leaves the offset alone for the insets the view already has, even an offset outside the scrollable range
      guard !newValue.isEqual(to: contentInsets) else {
        return
      }

      // AppKit moves the offset by the inset change, while UIKit keeps it and clamps each axis it leaves outside the new
      // range, so put the old offset back as AppKit clamps it: AppKit leaves an offset inside the range exactly where it
      // is, between pixels too, and moves one outside it, by any amount, to where AppKit's own scrolling would rest.
      // bounds notifications stay off meanwhile, so the view doesn't render for the offset AppKit moved to: turning them
      // back on posts one notification if the bounds changed.
      let contentOffset = self.contentOffset

      let postsBoundsChangedNotifications = contentView.postsBoundsChangedNotifications
      contentView.postsBoundsChangedNotifications = false

      contentInsets = newValue

      let keptContentOffset = contentView.constrainBoundsRect(CGRect(origin: contentOffset, size: contentView.bounds.size)).origin
      if self.contentOffset != keptContentOffset {
        setContentOffsetExactly(keptContentOffset)
      }

      contentView.postsBoundsChangedNotifications = postsBoundsChangedNotifications
    }
  }

  /// The insets in effect, including the automatic adjustments, like `UIScrollView`'s `adjustedContentInset`.
  ///
  /// It also includes the thickness of legacy scroll bars that AppKit places over the content.
  public var adjustedContentInset: EdgeInsets {
    contentView.contentInsets
  }

  /// The size of the visible area in content coordinates, like `UIScrollView`'s `visibleSize`.
  ///
  /// It's exact, while the clip view rounds its own size to whole pixels.
  public var visibleSize: CGSize {
    let boundsSize = contentView.bounds.size
    let frameSize = contentView.frame.size
    guard let size = (contentView as? ScrollClipView)?.unroundedSize, frameSize.width > 0, frameSize.height > 0 else {
      return boundsSize
    }
    // the clip view's bounds are its frame in content coordinates, which magnification or a caller can scale differently
    // along each axis, so the size the clip view was given scales the same way
    return CGSize(width: size.width * (boundsSize.width / frameSize.width), height: size.height * (boundsSize.height / frameSize.height))
  }

  override public init(frame: CGRect) {
    super.init(frame: frame)

    updateCommonSettings()

    contentView = ScrollClipView()
    documentView = Self.makeDocumentView()

    startObservingBoundsChange()
  }

  deinit {
    stopObservingBoundsChange()

    // a display link keeps a keyboard scroll in flight alive, and the scroll can't go on without the scroll view
    if #available(macOS 14.0, *) {
      keyboardScrollAnimation?.stop()
    }
  }

  override open func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    // the display link of a keyboard scroll in flight follows the window's screen, so the scroll stops with the window
    if window == nil, #available(macOS 14.0, *) {
      keyboardScrollAnimation?.stop()
    }
  }

  /// Returns a new view to hold the scroll view's content, which the scroll view makes once, when it's made.
  class func makeDocumentView() -> NSView {
    ScrollDocumentView()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  // MARK: - Layout

  override open func layout() {
    super.layout()

    updateScrollElasticity()

    layoutSubviews()
  }

  open func layoutSubviews() {}

  // MARK: - Observe bounds change

  private var observingBoundsChangeToken: Any?

  private func startObservingBoundsChange() {
    contentView.postsBoundsChangedNotifications = true
    observingBoundsChangeToken = NotificationCenter.default.addObserver(
      forName: NSView.boundsDidChangeNotification,
      object: contentView,
      queue: nil,
      using: { [weak self] notification in
        guard let self else {
          return
        }
        ComposeUI.assert((notification.object as? NSClipView) === self.contentView)
        self.layoutSubviews()
      }
    )
  }

  func stopObservingBoundsChange() {
    if let observingBoundsChangeToken {
      NotificationCenter.default.removeObserver(
        observingBoundsChangeToken,
        name: NSView.boundsDidChangeNotification,
        object: contentView
      )
    }
    contentView.postsBoundsChangedNotifications = false
  }

  // MARK: - Scroll

  /// Whether scrolling is enabled, like `UIScrollView`'s `isScrollEnabled`.
  ///
  /// While scrolling is disabled, the scroll view passes scroll wheel events to its next responder.
  public var isScrollEnabled: Bool = true

  /// A trackpad or Magic Mouse scroll, latched to the scroll view that took it.
  private struct ScrollLatch {

    /// The scroll view that took the scroll, which gets all of the scroll's events.
    weak var scrollView: ScrollView?

    /// Whether the scroll view handles the scroll, instead of passing it to its next responder.
    let handlesScroll: Bool

    /// The timestamp of the latest event that the scroll view got.
    var timestamp: TimeInterval

    /// Whether the latest event that the scroll view got is a `mayBegin` event.
    var isMayBegin: Bool

    /// Whether the scroll ended without a glide, so that no gesture continues it.
    var endedWithoutGlide: Bool

    init(scrollView: ScrollView, handlesScroll: Bool, timestamp: TimeInterval) {
      self.scrollView = scrollView
      self.handlesScroll = handlesScroll
      self.timestamp = timestamp
      self.isMayBegin = false
      self.endedWithoutGlide = false
    }
  }

  /// The trackpad or Magic Mouse scroll in progress, latched to the scroll view that took it. Main thread only.
  ///
  /// Overriding `scrollWheel(with:)` opts the scroll views out of AppKit's responsive scrolling, so AppKit sends each
  /// event to the view under the pointer, even in the middle of a gesture or its glide, instead of keeping the scroll
  /// with the scroll view it started on, as it does for its own scroll views. The scroll views keep the scroll with that
  /// scroll view themselves, so that a nested scroll view that the content moves under the pointer doesn't take it over.
  private static var latch: ScrollLatch?

  override open func scrollWheel(with event: NSEvent) {
    // a gesture that's cancelled, or that ends right after `mayBegin` because resting fingers lift without moving, ends
    // the scroll without a glide, so the next gesture comes from a new touch. AppKit sends that last event to the view
    // under the pointer, which can be outside the latched scroll view, or in a scroll view whose scrolling is disabled,
    // so whichever scroll view gets it ends the scroll, before passing it on
    let phase = event.phase
    if phase == .cancelled || (phase == .ended && Self.latch?.isMayBegin == true) {
      Self.latch?.endedWithoutGlide = true
    }

    // https://apptyrant.com/2015/05/18/how-to-disable-nsscrollview-scrolling/
    guard isScrollEnabled else {
      // send the event to outside of the scroll view.
      // https://github.com/onmyway133/blog/issues/733
      nextResponder?.scrollWheel(with: event)
      return
    }

    if handles(event) {
      let remainingEvent = bringContentOffsetIntoScrollableRange(for: event)
      super.scrollWheel(with: droppingDeltasAlongFixedAxes(of: remainingEvent))
    } else {
      nextResponder?.scrollWheel(with: event)
    }
  }

  /// Returns whether the scroll view handles the scroll wheel event, instead of passing it to its next responder.
  private func handles(_ event: NSEvent) -> Bool {
    let phase = event.phase

    // a mouse wheel event has neither phase, and AppKit sends each one to the view under the pointer, even for its own
    // scroll views, so each one starts a scroll of its own instead of following the latched scroll
    guard !phase.isEmpty || !event.momentumPhase.isEmpty else {
      return takesScroll(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY, canBounce: false)
    }

    guard var latch = Self.latch, let latchedScrollView = latch.scrollView, self.isDescendant(of: latchedScrollView) else {
      switch phase {
      case .mayBegin,
           .began:
        return startsScroll(with: event)
      default:
        // a scroll that another scroll view took isn't for this one, even once that scroll view is deallocated, while a
        // scroll that no scroll view took, such as resting fingers, goes to the scroll view under the pointer
        return Self.latch == nil
      }
    }

    switch phase {
    case .mayBegin,
         .began:
      // a touch on the trackpad ends a glide before the touch's first event comes, so a gesture that starts shortly
      // after the scroll's latest event continues the scroll, as a gesture during a glide does on AppKit's own scroll
      // views and on UIKit. resting fingers start a gesture with a `mayBegin` event, and its `began` event follows when
      // they move, however late. a latched scroll view whose scrolling is disabled can't take the gesture, so it starts
      // a scroll of its own.
      guard !latch.endedWithoutGlide, latchedScrollView.isScrollEnabled,
            event.timestamp - latch.timestamp < Constants.latchingInterval || (phase == .began && latch.isMayBegin)
      else {
        return startsScroll(with: event)
      }
    default:
      break
    }

    guard latchedScrollView === self else {
      // the latched scroll view is an ancestor, which gets the event through the responder chain
      return false
    }

    latch.timestamp = event.timestamp
    latch.isMayBegin = phase == .mayBegin
    Self.latch = latch
    return latch.handlesScroll
  }

  /// Starts a scroll with the first event of a gesture, and returns whether the scroll view handles the event.
  private func startsScroll(with event: NSEvent) -> Bool {
    switch event.phase {
    case .mayBegin:
      // resting fingers have no direction to choose a scroll view by, so the scroll view under the pointer gets the
      // event, and the gesture's `began` event chooses one if the fingers move
      Self.latch = nil
      return true
    default:
      // each scroll view that the event reaches latches the scroll in turn, so the scroll stays with the one that handles
      // it, or with the outermost one, which passes it on to a responder outside the scroll views
      let handlesScroll = takesScroll(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY, canBounce: true)
      Self.latch = ScrollLatch(scrollView: self, handlesScroll: handlesScroll, timestamp: event.timestamp)
      return handlesScroll
    }
  }

  /// Returns whether the scroll view takes a scroll that starts with the deltas, instead of passing it to a parent
  /// scroll view.
  ///
  /// - Parameters:
  ///   - deltaX: The horizontal scroll delta.
  ///   - deltaY: The vertical scroll delta.
  ///   - canBounce: Whether the scroll can bounce past the ends of the scrollable range, which a mouse wheel scroll can't.
  private func takesScroll(deltaX: CGFloat, deltaY: CGFloat, canBounce: Bool) -> Bool {
    // the scroll view takes the scroll if any of these is true, and otherwise passes it to a parent scroll view:
    // 1. its offset is outside the scrollable range, for example set in code or still bouncing back. the offset comes
    //    back into the range only in the scroll view that handles the scroll.
    // 2. it always bounces in the scroll's direction, and the scroll can bounce.
    // 3. it can scroll in the scroll's direction.
    // 4. no parent scroll view can scroll in the scroll's direction either, so it keeps the scroll and can bounce.
    // a positive delta scrolls toward the top or the left.
    let bouncesHorizontally = canBounce && alwaysBounceHorizontal
    let bouncesVertically = canBounce && alwaysBounceVertical
    return isContentOffsetOutsideScrollableRange ||
      (deltaY > 0 && (bouncesVertically || canScrollToTop || !hasParentScrollView { $0.canScrollToTop })) ||
      (deltaY < 0 && (bouncesVertically || canScrollToBottom || !hasParentScrollView { $0.canScrollToBottom })) ||
      (deltaX > 0 && (bouncesHorizontally || canScrollToLeft || !hasParentScrollView { $0.canScrollToLeft })) ||
      (deltaX < 0 && (bouncesHorizontally || canScrollToRight || !hasParentScrollView { $0.canScrollToRight }))
  }

  /// Brings the content offset back into the scrollable range along each axis where it's outside, for a mouse wheel
  /// event.
  ///
  /// AppKit doesn't bring it back itself: since macOS 27, a scroll view that opts out of responsive scrolling, as
  /// overriding `scrollWheel(with:)` does, leaves the offset outside the range on a mouse wheel event, while it still
  /// springs the offset back after a trackpad gesture.
  ///
  /// - Parameter event: The scroll wheel event.
  /// - Returns: The event without its scroll delta along the axes where the offset came back.
  private func bringContentOffsetIntoScrollableRange(for event: NSEvent) -> NSEvent {
    let isOutsideHorizontalRange = isContentOffsetOutsideHorizontalScrollableRange
    let isOutsideVerticalRange = isContentOffsetOutsideVerticalScrollableRange
    guard event.phase.isEmpty, event.momentumPhase.isEmpty, isOutsideHorizontalRange || isOutsideVerticalRange else {
      return event
    }

    // an axis outside the range comes back to where AppKit's own scrolling would rest
    let restingContentOffset = contentView.constrainBoundsRect(CGRect(origin: contentOffset, size: contentView.bounds.size)).origin
    setContentOffsetExactly(
      CGPoint(
        x: isOutsideHorizontalRange ? restingContentOffset.x : contentOffset.x,
        y: isOutsideVerticalRange ? restingContentOffset.y : contentOffset.y
      )
    )

    return droppingDeltas(of: event, horizontally: isOutsideHorizontalRange, vertically: isOutsideVerticalRange)
  }

  /// Returns the event without its scroll delta along an axis the scroll view has no room to scroll along, while the
  /// content offset is inside the scrollable range.
  ///
  /// AppKit compares the content with the clip view, which it rounds to whole pixels, so content that fits the exact
  /// visible size can look a fraction of a point larger, and AppKit would scroll it by a pixel.
  private func droppingDeltasAlongFixedAxes(of event: NSEvent) -> NSEvent {
    // a mouse wheel event has no phase and can't spring back, so along an axis without room, it would only move the
    // content by that pixel, even when the axis bounces. an offset outside the range, for example set in code, keeps a
    // gesture's delta, since AppKit then moves the content to bring it back into the range, not by the rounding
    let isMouseWheel = event.phase.isEmpty && event.momentumPhase.isEmpty

    let dropsHorizontalDelta = event.scrollingDeltaX != 0 &&
      (isMouseWheel || !alwaysBounceHorizontal) &&
      !hasHorizontalScrollRange &&
      !isContentOffsetOutsideHorizontalScrollableRange

    let dropsVerticalDelta = event.scrollingDeltaY != 0 &&
      (isMouseWheel || !alwaysBounceVertical) &&
      !hasVerticalScrollRange &&
      !isContentOffsetOutsideVerticalScrollableRange

    return droppingDeltas(of: event, horizontally: dropsHorizontalDelta, vertically: dropsVerticalDelta)
  }

  /// Returns the event without its scroll deltas along the axes.
  ///
  /// - Parameters:
  ///   - event: The scroll wheel event.
  ///   - horizontally: Whether to drop the horizontal delta.
  ///   - vertically: Whether to drop the vertical delta.
  private func droppingDeltas(of event: NSEvent, horizontally: Bool, vertically: Bool) -> NSEvent {
    guard horizontally || vertically, let cgEvent = event.cgEvent?.copy() else {
      return event
    }

    if horizontally {
      cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 0)
      cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 0)
      cgEvent.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: 0)
    }
    if vertically {
      cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
      cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
      cgEvent.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
    }
    return NSEvent(cgEvent: cgEvent) ?? event
  }

  /// Whether the horizontal scroll indicator is shown. For UIKit compatibility, this is the same as `hasHorizontalScroller`.
  @inlinable
  @inline(__always)
  public var showsHorizontalScrollIndicator: Bool {
    get {
      hasHorizontalScroller
    }
    set {
      hasHorizontalScroller = newValue
    }
  }

  /// Whether the vertical scroll indicator is shown. For UIKit compatibility, this is the same as `hasVerticalScroller`.
  @inlinable
  @inline(__always)
  public var showsVerticalScrollIndicator: Bool {
    get {
      hasVerticalScroller
    }
    set {
      hasVerticalScroller = newValue
    }
  }

  /// Flash the scroll indicators.
  public func flashScrollIndicators() {
    flashScrollers()
  }

  // MARK: - Always bounces

  public var alwaysBounceVertical: Bool = false {
    didSet {
      guard alwaysBounceVertical != oldValue else {
        return
      }

      invalidateScrollElasticity()
    }
  }

  public var alwaysBounceHorizontal: Bool = false {
    didSet {
      guard alwaysBounceHorizontal != oldValue else {
        return
      }

      invalidateScrollElasticity()
    }
  }

  private var hasPendingScrollElasticityUpdate: Bool = false

  /// Invalidate the scroll elasticity.
  ///
  /// This will trigger a scroll elasticity update on the next run loop based on the content size and the bounds.
  public func invalidateScrollElasticity() {
    guard !hasPendingScrollElasticityUpdate else {
      return
    }

    hasPendingScrollElasticityUpdate = true

    RunLoop.main.perform(inModes: [.common]) { [weak self] in
      guard let self else {
        return
      }

      self.hasPendingScrollElasticityUpdate = false
      self.updateScrollElasticity()
    }
  }

  private func updateScrollElasticity() {
    horizontalScrollElasticity = alwaysBounceHorizontal || hasHorizontalScrollRange ? .allowed : .none
    verticalScrollElasticity = alwaysBounceVertical || hasVerticalScrollRange ? .allowed : .none
  }

  // The properties below use the scroll range, which counts the content insets and the exact visible size: the clip
  // view rounds its size to whole pixels, so content as large as the view would otherwise look a fraction of a point
  // larger.

  /// Whether the scroll view has room to scroll horizontally.
  private var hasHorizontalScrollRange: Bool {
    maxOffsetX.extends(beyond: minOffsetX)
  }

  /// Whether the scroll view has room to scroll vertically.
  private var hasVerticalScrollRange: Bool {
    maxOffsetY.extends(beyond: minOffsetY)
  }

  // MARK: - Keyboard

  // The arrow and page keys scroll the scroll view while the keyboard focus is in it, as UIKit's keyboard scrolling does.
  // AppKit sends the scroll view the actions of these keys when no view between the focused view and the scroll view
  // handles them, and the scroll view passes each action on to its next responder when it can't scroll toward the key,
  // so that the innermost scroll view that can scroll toward it scrolls, as with a mouse wheel.

  /// Whether the arrow and page keys can scroll the scroll view: its scrolling is enabled, and it has room to scroll.
  ///
  /// The view that holds the content takes the keyboard focus only then, so that a scroll view that the keys can't scroll
  /// doesn't take the focus from another view.
  var canScrollWithKeyboard: Bool {
    isScrollEnabled && (hasHorizontalScrollRange || hasVerticalScrollRange)
  }

  override open func mouseDown(with event: NSEvent) {
    focusContent(for: event)

    super.mouseDown(with: event)
  }

  /// Scrolls the content up by a line, or passes the action on when the scroll view can't scroll up.
  override open func moveUp(_ sender: Any?) {
    if isScrollEnabled, canScrollToTop {
      scrollContent(by: CGPoint(x: 0, y: -Constants.keyboardLineScrollDistance))
    } else {
      nextResponder?.tryToPerform(#selector(moveUp(_:)), with: sender)
    }
  }

  /// Scrolls the content down by a line, or passes the action on when the scroll view can't scroll down.
  override open func moveDown(_ sender: Any?) {
    if isScrollEnabled, canScrollToBottom {
      scrollContent(by: CGPoint(x: 0, y: Constants.keyboardLineScrollDistance))
    } else {
      nextResponder?.tryToPerform(#selector(moveDown(_:)), with: sender)
    }
  }

  /// Scrolls the content left by a line, or passes the action on when the scroll view can't scroll left.
  override open func moveLeft(_ sender: Any?) {
    if isScrollEnabled, canScrollToLeft {
      scrollContent(by: CGPoint(x: -Constants.keyboardLineScrollDistance, y: 0))
    } else {
      nextResponder?.tryToPerform(#selector(moveLeft(_:)), with: sender)
    }
  }

  /// Scrolls the content right by a line, or passes the action on when the scroll view can't scroll right.
  override open func moveRight(_ sender: Any?) {
    if isScrollEnabled, canScrollToRight {
      scrollContent(by: CGPoint(x: Constants.keyboardLineScrollDistance, y: 0))
    } else {
      nextResponder?.tryToPerform(#selector(moveRight(_:)), with: sender)
    }
  }

  /// Scrolls the content up by a page, or passes the action on when the scroll view can't scroll up.
  override open func pageUp(_ sender: Any?) {
    if isScrollEnabled, canScrollToTop {
      if scrollsWithKeyboardOnSpring, #available(macOS 14.0, *) {
        animateKeyboardScroll(by: CGPoint(x: 0, y: -keyboardPageScrollDistance))
      } else {
        super.pageUp(sender)
      }
    } else {
      nextResponder?.tryToPerform(#selector(pageUp(_:)), with: sender)
    }
  }

  /// Scrolls the content down by a page, or passes the action on when the scroll view can't scroll down.
  override open func pageDown(_ sender: Any?) {
    if isScrollEnabled, canScrollToBottom {
      if scrollsWithKeyboardOnSpring, #available(macOS 14.0, *) {
        animateKeyboardScroll(by: CGPoint(x: 0, y: keyboardPageScrollDistance))
      } else {
        super.pageDown(sender)
      }
    } else {
      nextResponder?.tryToPerform(#selector(pageDown(_:)), with: sender)
    }
  }

  /// Scrolls the content up by a page for a view that interprets its keys, as `pageUp(_:)` does.
  ///
  /// A view that interprets its keys with `interpretKeyEvents(_:)` sends the page keys as `scrollPageUp(_:)` and
  /// `scrollPageDown(_:)`, which AppKit's scroll view doesn't handle. So when the scroll view can't scroll up, it passes
  /// on `pageUp(_:)`, which the scroll views around it handle, AppKit's too.
  override open func scrollPageUp(_ sender: Any?) {
    pageUp(sender)
  }

  /// Scrolls the content down by a page for a view that interprets its keys, as `pageDown(_:)` does, see
  /// `scrollPageUp(_:)`.
  override open func scrollPageDown(_ sender: Any?) {
    pageDown(sender)
  }

  /// Gives the keyboard focus to the content for a click in the scroll view, unless the click landed in the view that
  /// has the focus in the scroll view.
  ///
  /// AppKit gives the first responder to the view under the pointer only if that view accepts it, so a click on content
  /// that doesn't accept it, which passes up the responder chain, focuses the content here. A nested scroll view gets
  /// the click first, so the focus that it takes stays with it as the click goes on to the scroll views around it.
  ///
  /// - Parameter event: The mouse down event.
  private func focusContent(for event: NSEvent) {
    let documentView = contentContainerView
    guard let window, documentView.acceptsFirstResponder else {
      return
    }

    if let firstResponder = window.firstResponder as? NSView, firstResponder.isDescendant(of: self) {
      let hitView = window.contentView?.superview?.hitTest(event.locationInWindow)
      if hitView?.isDescendant(of: firstResponder) == true {
        return
      }
    }

    window.makeFirstResponder(documentView)
  }

  /// Scrolls the content by a distance for an arrow key, on a spring as UIKit's keyboard scrolling does, or as AppKit
  /// scrolls for the keyboard.
  ///
  /// - Parameter distance: The distance to scroll by, in content coordinates.
  private func scrollContent(by distance: CGPoint) {
    if scrollsWithKeyboardOnSpring, #available(macOS 14.0, *) {
      animateKeyboardScroll(by: distance)
    } else {
      // AppKit animates a scroll that `NSView.scroll(_:)` makes while it handles a key that scrolls, unless the user
      // reduces motion, and moves a scroll made during the animation from where the animation goes, so that each press
      // of a key held down scrolls by the whole distance. `NSView.scroll(_:)` scrolls the clip view around the view it's
      // called on, so it's called on the document view, with the offset in the document view's coordinates
      let documentView = contentContainerView
      let offset = contentOffset
      let target = CGPoint(x: offset.x + distance.x, y: offset.y + distance.y)
      documentView.scroll(documentView.convert(target, from: contentView))
    }
  }

  // MARK: - Keyboard Scroll Animation

  /// The animation that moves the content for the keys on a spring, `nil` before the first key that moves it.
  ///
  /// It's kept as `AnyObject`, since its type is available from macOS 14, where the display link that it runs on is.
  private var keyboardScrollAnimationStorage: AnyObject?

  /// The animation that moves the content for the keys on a spring, `nil` before the first key that moves it.
  @available(macOS 14.0, *)
  var keyboardScrollAnimation: KeyboardScrollAnimation? {
    keyboardScrollAnimationStorage as? KeyboardScrollAnimation
  }

  /// Whether the keys scroll the content on a spring: not when the user reduces motion, for which AppKit's own scrolling
  /// doesn't animate either.
  private var scrollsWithKeyboardOnSpring: Bool {
    #if DEBUG
    if let scrollsWithKeyboardOnSpringForTesting = Self.scrollsWithKeyboardOnSpringForTesting {
      return scrollsWithKeyboardOnSpringForTesting
    }
    #endif

    return !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  #if DEBUG
  /// Whether the keys scroll the content on a spring in tests, which overrides the user's reduced motion when set.
  static var scrollsWithKeyboardOnSpringForTesting: Bool?
  #endif

  /// The distance that a page key scrolls the content, as AppKit's own page scrolling scrolls it: the visible height
  /// between the insets, less the overlap that `verticalPageScroll` keeps in view, or half that height when it's shorter
  /// than the overlap.
  private var keyboardPageScrollDistance: CGFloat {
    let insets = adjustedContentInset
    let height = contentView.bounds.height - insets.top - insets.bottom
    return height < verticalPageScroll ? height / 2 : height - verticalPageScroll
  }

  /// Moves the content by a distance for a key on a spring, as UIKit's keyboard scrolling moves it on iPad.
  ///
  /// - Parameter distance: The distance to scroll by, in content coordinates.
  @available(macOS 14.0, *)
  private func animateKeyboardScroll(by distance: CGPoint) {
    let animation: KeyboardScrollAnimation
    if let keyboardScrollAnimation {
      animation = keyboardScrollAnimation
    } else {
      animation = KeyboardScrollAnimation(scrollView: self)
      keyboardScrollAnimationStorage = animation
    }
    animation.scroll(by: distance, at: AnimationClock.now)
  }

  /// Returns the content offset that a keyboard scroll shows for an offset: on whole pixels, in the scrollable range,
  /// where AppKit's own scrolling shows the content.
  ///
  /// - Parameter offset: The content offset that the scroll is at, or goes to.
  /// - Returns: The content offset that the scroll shows.
  func keyboardScrollOffset(for offset: CGPoint) -> CGPoint {
    let pixelSize = self.pixelSize
    return contentOffsetInScrollableRange(
      CGPoint(
        x: (offset.x / pixelSize.width).rounded() * pixelSize.width,
        y: (offset.y / pixelSize.height).rounded() * pixelSize.height
      )
    )
  }

  /// Returns the content offset in the scrollable range that's nearest to an offset.
  ///
  /// - Parameter offset: The content offset.
  /// - Returns: The content offset in the scrollable range.
  func contentOffsetInScrollableRange(_ offset: CGPoint) -> CGPoint {
    contentView.constrainBoundsRect(CGRect(origin: offset, size: contentView.bounds.size)).origin
  }

  // MARK: - Constants

  private enum Constants {

    /// How long after a latched scroll's latest event a gesture that starts continues the scroll.
    ///
    /// A touch that ends a glide on a trackpad sends its first event 40 to 75 ms after the glide's end.
    static let latchingInterval: TimeInterval = 0.1

    /// The distance that an arrow key scrolls the content, as UIKit's keyboard scrolling scrolls it.
    static let keyboardLineScrollDistance: CGFloat = 40
  }
}

private extension ScrollView {

  /// Whether the content offset is outside the scrollable range along either axis, by more than a pixel.
  var isContentOffsetOutsideScrollableRange: Bool {
    isContentOffsetOutsideHorizontalScrollableRange || isContentOffsetOutsideVerticalScrollableRange
  }

  // AppKit aligns where scrolling comes to rest to the window's pixels, which can leave the offset up to about a pixel
  // past an end of the exact range, so the properties below count an offset within a pixel of the range as inside it.
  // Along an axis where the content is smaller than the visible size, the maximum offset is below the minimum, and the
  // scrollable range is the minimum offset alone.

  /// Whether the content offset is outside the horizontal scrollable range, by more than a pixel.
  var isContentOffsetOutsideHorizontalScrollableRange: Bool {
    let x = contentOffset.x
    let pixel = pixelSize.width
    let minX = minOffsetX
    return x < minX - pixel || x > max(minX, maxOffsetX) + pixel
  }

  /// Whether the content offset is outside the vertical scrollable range, by more than a pixel.
  var isContentOffsetOutsideVerticalScrollableRange: Bool {
    let y = contentOffset.y
    let pixel = pixelSize.height
    let minY = minOffsetY
    return y < minY - pixel || y > max(minY, maxOffsetY) + pixel
  }

  /// Whether the view has a parent scroll view that satisfies the condition.
  func hasParentScrollView(_ condition: (ScrollView) -> Bool) -> Bool {
    var parent = superview
    while let view = parent {
      if let scrollView = view as? ScrollView, condition(scrollView) {
        return true
      }
      parent = view.superview
    }
    return false
  }
}

/// A clip view that keeps the size AppKit tiles it to, before it rounds that size to whole pixels.
private final class ScrollClipView: NSClipView {

  /// The size AppKit last set, before the clip view rounded it.
  private(set) var unroundedSize: CGSize?

  override func setFrameSize(_ newSize: NSSize) {
    unroundedSize = newSize

    super.setFrameSize(newSize)
  }
}

#endif

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

public typealias ScrollView = UIScrollView
#endif

extension ScrollView {

  /// The view that holds the scroll view's content: the document view on AppKit, and the scroll view itself on UIKit.
  var contentContainerView: View {
    #if canImport(AppKit)
    return documentView! // swiftlint:disable:this force_unwrapping
    #endif

    #if canImport(UIKit)
    return self
    #endif
  }

  /// Sets the content offset as given, without rounding it to whole pixels, to keep an offset that the platform's own
  /// scrolling left between pixels.
  ///
  /// - Parameter offset: The content offset.
  func setContentOffsetExactly(_ offset: CGPoint) {
    #if canImport(AppKit)
    // `NSClipView.scroll(to:)` keeps the point as given, while `NSView.scroll(_:)` clamps it into the scrollable range
    // and adds floating-point noise
    contentView.scroll(to: offset)
    reflectScrolledClipView(contentView)
    #endif

    #if canImport(UIKit)
    // UIKit rounds a set `contentOffset` to whole pixels, while assigning the bounds origin keeps it
    bounds.origin = offset
    #endif
  }

  /// The size of a pixel in content coordinates.
  var pixelSize: CGSize {
    #if canImport(AppKit)
    // the clip view's coordinates are the content coordinates, so converting from them includes the magnification and
    // any scaling of the bounds. each axis converts a unit vector and takes its length, since a rotation would mix the
    // axes of a converted size.
    let unitX = contentView.convertToBacking(CGSize(width: 1, height: 0))
    let unitY = contentView.convertToBacking(CGSize(width: 0, height: 1))
    return CGSize(width: 1 / hypot(unitX.width, unitX.height), height: 1 / hypot(unitY.width, unitY.height))
    #endif

    #if canImport(UIKit)
    // the content offset is in the scroll view's own points, which zooming doesn't scale
    let length = 1 / windowScaleFactor
    return CGSize(width: length, height: length)
    #endif
  }
}
