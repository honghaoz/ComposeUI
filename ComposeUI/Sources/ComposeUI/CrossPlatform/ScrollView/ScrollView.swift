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
    documentView = BaseView()

    startObservingBoundsChange()
  }

  deinit {
    stopObservingBoundsChange()
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

    init(scrollView: ScrollView, handlesScroll: Bool, timestamp: TimeInterval) {
      self.scrollView = scrollView
      self.handlesScroll = handlesScroll
      self.timestamp = timestamp
      self.isMayBegin = false
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
    // https://apptyrant.com/2015/05/18/how-to-disable-nsscrollview-scrolling/
    guard isScrollEnabled else {
      // send the event to outside of the scroll view.
      // https://github.com/onmyway133/blog/issues/733
      nextResponder?.scrollWheel(with: event)
      return
    }

    if handles(event) {
      super.scrollWheel(with: droppingDeltasAlongFixedAxes(of: event))
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
        // a scroll that a scroll view outside this one took isn't for this one, while a scroll that no scroll view took,
        // such as resting fingers, goes to the scroll view under the pointer
        return Self.latch?.scrollView == nil
      }
    }

    switch phase {
    case .mayBegin,
         .began:
      // a touch on the trackpad ends a glide before the touch's first event comes, so a gesture that starts shortly
      // after the scroll's latest event continues the scroll, as a gesture during a glide does on AppKit's own scroll
      // views and on UIKit. resting fingers start a gesture with a `mayBegin` event, and its `began` event follows when
      // they move, however late.
      guard event.timestamp - latch.timestamp < Constants.latchingInterval || (phase == .began && latch.isMayBegin) else {
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
    // 1. its offset is outside the scrollable range, for example set in code or still bouncing back. AppKit brings the
    //    offset back into the range only for the scroll view that handles the scroll.
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

  /// Returns the event without its scroll delta along an axis the scroll view has no room to scroll along, while the
  /// content offset is inside the scrollable range.
  ///
  /// AppKit compares the content with the clip view, which it rounds to whole pixels, so content that fits the exact
  /// visible size can look a fraction of a point larger, and AppKit would scroll it by a pixel.
  private func droppingDeltasAlongFixedAxes(of event: NSEvent) -> NSEvent {
    // a mouse wheel event has no phase and can't spring back, so along an axis without room, it would only move the
    // content by that pixel, even when the axis bounces. an offset outside the range, for example set in code, keeps
    // the delta, since AppKit then moves the content to bring it back into the range, not by the rounding
    let isMouseWheel = event.phase.isEmpty && event.momentumPhase.isEmpty

    let dropsHorizontalDelta = event.scrollingDeltaX != 0 &&
      (isMouseWheel || !alwaysBounceHorizontal) &&
      !hasHorizontalScrollRange &&
      !isContentOffsetOutsideHorizontalScrollableRange

    let dropsVerticalDelta = event.scrollingDeltaY != 0 &&
      (isMouseWheel || !alwaysBounceVertical) &&
      !hasVerticalScrollRange &&
      !isContentOffsetOutsideVerticalScrollableRange

    guard dropsHorizontalDelta || dropsVerticalDelta, let cgEvent = event.cgEvent?.copy() else {
      return event
    }

    if dropsHorizontalDelta {
      cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 0)
      cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 0)
      cgEvent.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: 0)
    }
    if dropsVerticalDelta {
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

  // MARK: - Constants

  private enum Constants {

    /// How long after a latched scroll's latest event a gesture that starts continues the scroll.
    ///
    /// A touch that ends a glide on a trackpad sends its first event 40 to 75 ms after the glide's end.
    static let latchingInterval: TimeInterval = 0.1
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
