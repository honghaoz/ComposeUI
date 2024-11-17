//
//  BaseScrollView.swift
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
#endif

#if canImport(UIKit)
import UIKit
#endif

/// A base scroll view.
///
/// The scroll view will automatically update the content scale factor when the window backing properties change.
open class BaseScrollView: ScrollView {

  override public init(frame: CGRect) {
    super.init(frame: frame)

    contentScaleFactor = screenScaleFactor
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  // MARK: - Scroll

  /// Whether the scroll view is scrollable.
  ///
  /// If set to `false`, the scroll view will disable scrolling to top and the scroll indicators will be hidden.
  public var isScrollable: Bool {
    get {
      #if canImport(UIKit)
      return isScrollEnabled
      #endif

      #if canImport(AppKit)
      return _isScrollable
      #endif
    }
    set {
      #if canImport(UIKit)
      isScrollEnabled = newValue
      if newValue == false {
        scrollsToTop = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
      }
      #endif

      #if canImport(AppKit)
      _isScrollable = newValue
      if newValue == false {
        hasHorizontalScroller = false
        hasVerticalScroller = false
      }
      #endif
    }
  }

  #if canImport(AppKit)
  private var _isScrollable: Bool = true

  override open func scrollWheel(with event: NSEvent) {
    // https://apptyrant.com/2015/05/18/how-to-disable-nsscrollview-scrolling/
    if _isScrollable {
      super.scrollWheel(with: event)
    } else {
      // send the event to outside of the scroll view.
      // https://github.com/onmyway133/blog/issues/733
      nextResponder?.scrollWheel(with: event)
    }
  }
  #endif

  // MARK: - Content Scale Factor

  #if canImport(AppKit)

  private weak var previousWindow: NSWindow?
  private var observingWindowBackingPropertiesToken: Any?

  override open func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    updateContentScaleFactor()

    startObservingWindowBackingProperties()

    previousWindow = window
  }

  private func startObservingWindowBackingProperties() {
    cancelObservingWindowBackingProperties()

    guard let window else {
      return
    }

    observingWindowBackingPropertiesToken = NotificationCenter.default.addObserver(
      forName: NSWindow.didChangeBackingPropertiesNotification,
      object: window,
      queue: nil,
      using: { [weak self] _ in
        self?.updateContentScaleFactor()
      }
    )
  }

  private func cancelObservingWindowBackingProperties() {
    if let token = observingWindowBackingPropertiesToken {
      NotificationCenter.default.removeObserver(token, name: NSWindow.didChangeBackingPropertiesNotification, object: previousWindow)
    }
  }
  #endif

  #if canImport(UIKit)
  override open func didMoveToWindow() {
    super.didMoveToWindow()

    updateContentScaleFactor()
  }
  #endif

  private func updateContentScaleFactor() {
    contentScaleFactor = screenScaleFactor

    // trigger a layout update to apply the new content scale factor.
    setNeedsLayout()
  }
}
