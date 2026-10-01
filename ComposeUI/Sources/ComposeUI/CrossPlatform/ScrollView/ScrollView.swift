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
  /// As on UIKit, setting it keeps the offset as set, even outside the scrollable range.
  public var contentOffset: CGPoint {
    get {
      contentView.bounds.origin
    }
    set {
      // `NSClipView.scroll(to:)` keeps the point as given, while `NSView.scroll(_:)` clamps it into the scrollable
      // range and adds floating-point noise
      contentView.scroll(to: newValue)
      reflectScrolledClipView(contentView)
    }
  }

  /// The custom distance that the content is inset from the scroll view's edges, like `UIScrollView`'s `contentInset`.
  ///
  /// This is `contentInsets`, which includes the automatic adjustments while `automaticallyAdjustsContentInsets` is on.
  public var contentInset: EdgeInsets {
    get {
      contentInsets
    }
    set {
      contentInsets = newValue
    }
  }

  /// The insets in effect, including the automatic adjustments, like `UIScrollView`'s `adjustedContentInset`.
  ///
  /// AppKit applies the automatic adjustments to `contentInsets` itself, so this is `contentInsets`.
  public var adjustedContentInset: EdgeInsets {
    contentInsets
  }

  /// The size of the visible area in content coordinates, like `UIScrollView`'s `visibleSize`.
  ///
  /// It's exact, while the clip view rounds its own size to whole pixels.
  public var visibleSize: CGSize {
    guard let size = (contentView as? ScrollClipView)?.unroundedSize else {
      return contentView.bounds.size
    }
    return CGSize(width: size.width / magnification, height: size.height / magnification)
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

  private var scrollSession: ScrollSession?

  override open func scrollWheel(with event: NSEvent) {
    // https://apptyrant.com/2015/05/18/how-to-disable-nsscrollview-scrolling/
    guard isScrollEnabled else {
      // send the event to outside of the scroll view.
      // https://github.com/onmyway133/blog/issues/733
      nextResponder?.scrollWheel(with: event)
      return
    }

    let scrollSession: ScrollSession
    if let currentScrollSession = self.scrollSession {
      if ScrollSession.isNewSession(with: event) {
        scrollSession = ScrollSession()
      } else {
        scrollSession = currentScrollSession
      }
    } else {
      scrollSession = ScrollSession()
    }
    self.scrollSession = scrollSession

    scrollSession.update(with: event, scrollView: self)

    switch scrollSession.target {
    case .handleBySelf:
      super.scrollWheel(with: event)
    case .passToOutside:
      nextResponder?.scrollWheel(with: event)
    }
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
    // compare the document with the exact visible size: the clip view rounds its size to whole pixels, so content as
    // large as the view would otherwise bounce by the leftover fraction
    if alwaysBounceHorizontal {
      horizontalScrollElasticity = .allowed
    } else {
      if contentContainerView.frame.width.extends(beyond: visibleSize.width) {
        horizontalScrollElasticity = .allowed
      } else {
        horizontalScrollElasticity = .none
      }
    }

    if alwaysBounceVertical {
      verticalScrollElasticity = .allowed
    } else {
      if contentContainerView.frame.height.extends(beyond: visibleSize.height) {
        verticalScrollElasticity = .allowed
      } else {
        verticalScrollElasticity = .none
      }
    }
  }
}

private final class ScrollSession {

  /// Whether the event is a new scroll session.
  static func isNewSession(with event: NSEvent) -> Bool {
    return event.phase == .began
  }

  private enum Phase {

    /// The phase of the scroll event.
    ///
    /// `phase` | `momentumPhase`
    /// --------+----------
    /// began   | 0
    /// changed | 0
    /// ...
    /// changed | 0
    /// ended   | 0
    /// 0       | began
    /// 0       | changed
    /// 0       | ...
    /// 0       | changed
    /// 0       | ended

    case scrollBegan
    case scrollChanged
    case scrollEnded
    case momentumBegan
    case momentumChanged
    case momentumEnded
  }

  private var phase: Phase = .scrollBegan

  enum Target {
    case handleBySelf
    case passToOutside
  }

  private(set) var target: Target = .handleBySelf

  init() {}

  func update(with event: NSEvent, scrollView: ScrollView) {
    switch event.phase {
    case .began:
      phase = .scrollBegan

      // decide if the scroll view should handle the scroll event by itself
      //
      // the core logic is: if the scroll view's offset is outside its scrollable range, for example set so in code or
      // still bouncing back, let it handle the scroll event, so that AppKit brings the offset back into the range. a
      // parent scroll view handling the event would leave the offset outside the range.
      // otherwise, given the scrolling direction, if the scroll view is configured to always bounce, or can scroll to
      // the direction, let it handle the scroll event.
      // otherwise, if the scroll view has a parent scroll view that can scroll to the direction, let the parent scroll
      // view handle the scroll event.
      // if there's no parent scroll view that can scroll to the direction, let the scroll view handle the scroll event
      // by itself so that it can bounce (elasticity).

      if scrollView.isContentOffsetOutsideScrollableRange ||
        (event.scrollingDeltaY > 0 && (scrollView.alwaysBounceVertical || scrollView.canScrollToTop || !scrollView.hasParentScrollView { $0.canScrollToTop })) ||
        (event.scrollingDeltaY < 0 && (scrollView.alwaysBounceVertical || scrollView.canScrollToBottom || !scrollView.hasParentScrollView { $0.canScrollToBottom })) ||
        (event.scrollingDeltaX > 0 && (scrollView.alwaysBounceHorizontal || scrollView.canScrollToLeft || !scrollView.hasParentScrollView { $0.canScrollToLeft })) ||
        (event.scrollingDeltaX < 0 && (scrollView.alwaysBounceHorizontal || scrollView.canScrollToRight || !scrollView.hasParentScrollView { $0.canScrollToRight }))
      {
        target = .handleBySelf
      } else {
        target = .passToOutside
      }
    case .changed:
      phase = .scrollChanged
    case .ended:
      phase = .scrollEnded
    default:
      if event.phase.rawValue == 0 {
        switch event.momentumPhase {
        case .began:
          phase = .momentumBegan
        case .changed:
          phase = .momentumChanged
        case .ended:
          phase = .momentumEnded
        default:
          break
        }
      }
    }
  }
}

private extension ScrollView {

  /// Whether the content offset is outside the scrollable range along either axis, by more than a pixel.
  ///
  /// Along an axis where the content is smaller than the visible size, the maximum offset is below the minimum, and the
  /// scrollable range is the minimum offset alone.
  var isContentOffsetOutsideScrollableRange: Bool {
    let offset = contentOffset
    // AppKit aligns where scrolling comes to rest to the window's pixels, which can leave the offset up to about a
    // pixel past an end of the exact range, so an offset within a pixel of the range counts as inside it
    let pixel = pixelSize
    let minX = minOffsetX
    let minY = minOffsetY
    return offset.x < minX - pixel.width || offset.x > max(minX, maxOffsetX) + pixel.width || offset.y < minY - pixel.height || offset.y > max(minY, maxOffsetY) + pixel.height
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
