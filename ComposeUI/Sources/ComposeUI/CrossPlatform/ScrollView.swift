//
//  ScrollView.swift
//  ComposeUI
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

    hasHorizontalScroller = true
    hasVerticalScroller = true

    // shows or hides scrollers when scroll view adjusts size
    // for example, when the scroll view becomes smaller that results into effective scrollers, this will show up the scroller
    autohidesScrollers = true

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

  // MARK: - Always bounces

  public var alwaysBounceVertical: Bool = false

  public var alwaysBounceHorizontal: Bool = false

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
#endif

#if canImport(UIKit)
import UIKit

public typealias ScrollView = UIScrollView
#endif
