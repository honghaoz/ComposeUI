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

#if canImport(AppKit)
import AppKit

/// A scroll view, like `UIScrollView` in UIKit.
open class ScrollView: NSScrollView {

  override open var wantsUpdateLayer: Bool { true }

  override open var isFlipped: Bool { true }

  override open var contentSize: CGSize {
    get {
      documentView().bounds.size
    }
    set {
      assert(documentView().frame.origin == .zero)
      documentView().frame = CGRect(origin: .zero, size: newValue)
    }
  }

  override public init(frame: CGRect) {
    super.init(frame: frame)

    updateCommonSettings()

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
        assert((notification.object as? NSClipView) === self.contentView)
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

  // MARK: - Document View

  /// Get the document view.
  /// - Returns: The document view.
  public func documentView() -> NSView {
    documentView! // swiftlint:disable:this force_unwrapping
  }

  // MARK: - Scroll

  private var scrollSession: ScrollSession?

  override open func scrollWheel(with event: NSEvent) {
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
    if alwaysBounceHorizontal {
      horizontalScrollElasticity = .allowed
    } else {
      if documentView().frame.width <= super.contentSize.width {
        horizontalScrollElasticity = .none
      } else {
        horizontalScrollElasticity = .allowed
      }
    }

    if alwaysBounceVertical {
      verticalScrollElasticity = .allowed
    } else {
      if documentView().frame.height <= super.contentSize.height {
        verticalScrollElasticity = .none
      } else {
        verticalScrollElasticity = .allowed
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
      // the core logic is: given the scrolling direction, if the scroll view is configured to always bounce, or can scroll to the direction, let it handle the scroll event.
      // otherwise, if the scroll view has a parent scroll view that can scroll to the direction, let the parent scroll view handle the scroll event.
      // if there's no parent scroll view that can scroll to the direction, let the scroll view handle the scroll event by itself so that it can bounce (elasticity).

      if (event.scrollingDeltaY > 0 && (scrollView.alwaysBounceVertical || scrollView.canScrollToTop || !scrollView.hasParentScrollView { $0.canScrollToTop })) ||
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

#endif

#if canImport(UIKit)
import UIKit

public typealias ScrollView = UIScrollView
#endif
