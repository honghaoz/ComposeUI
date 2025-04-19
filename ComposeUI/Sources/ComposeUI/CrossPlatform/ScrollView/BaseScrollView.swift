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

import Combine

/// A base scroll view.
///
/// The scroll view will automatically update the content scale factor when the window backing properties change.
open class BaseScrollView: ScrollView {

  override public init(frame: CGRect) {
    super.init(frame: frame)

    contentScaleFactor = windowScaleFactor

    #if canImport(AppKit)
    startObservingAppearance()
    #endif
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  deinit {
    #if canImport(AppKit)
    cancelObservingAppearance()
    #endif
  }

  #if canImport(AppKit)
  override open func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()

    if theme != previousTheme {
      scheduleThemeUpdate(theme)
    }
  }
  #endif

  #if canImport(UIKit)
  override open func didMoveToSuperview() {
    super.didMoveToSuperview()

    if theme != previousTheme {
      scheduleThemeUpdate(theme)
    }
  }
  #endif

  // MARK: - Scroll

  /// Whether the scroll view is scrollable.
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
      #endif

      #if canImport(AppKit)
      _isScrollable = newValue
      #endif
    }
  }

  #if canImport(AppKit)
  private var _isScrollable: Bool = true

  override open func scrollWheel(with event: NSEvent) {
    // https://apptyrant.com/2015/05/18/how-to-disable-nsscrollview-scrolling/
    guard _isScrollable else {
      // send the event to outside of the scroll view.
      // https://github.com/onmyway133/blog/issues/733
      nextResponder?.scrollWheel(with: event)
      return
    }

    super.scrollWheel(with: event)
  }
  #endif

  // MARK: - Theme

  /// A publisher that emits the theme of the view.
  ///
  /// The publisher emits the current theme when subscribed.
  public private(set) lazy var themePublisher: AnyPublisher<Theme, Never> = themeSubject.compactMap { $0 }.eraseToAnyPublisher()

  private lazy var themeSubject = CurrentValueSubject<Theme?, Never>(nil)

  private var pendingThemeToUpdate: Theme?
  private func scheduleThemeUpdate(_ newTheme: Theme) {
    if pendingThemeToUpdate == nil {
      // no pending theme update, schedule an update
      RunLoop.main.perform(inModes: [.common]) { [weak self] in
        guard let self, let newTheme = self.pendingThemeToUpdate else {
          return
        }

        self.pendingThemeToUpdate = nil
        self.updateTheme(newTheme)
      }
    }

    pendingThemeToUpdate = newTheme
  }

  private var previousTheme: Theme? {
    themeSubject.value
  }

  private func updateTheme(_ newTheme: Theme) {
    guard previousTheme != newTheme else {
      return
    }

    themeSubject.value = newTheme
  }

  #if canImport(AppKit)
  /// The theme of the view.
  public var theme: Theme {
    effectiveAppearance.theme
  }

  /// The override theme of the view.
  public var overrideTheme: Theme? {
    get {
      appearance?.theme ?? nil
    }
    set {
      if let newValue {
        appearance = NSAppearance(named: newValue.isLight ? .aqua : .darkAqua)
      } else {
        appearance = nil
      }
    }
  }

  private var appearanceObserver: NSKeyValueObservation?

  private func startObservingAppearance() {
    guard appearanceObserver == nil else {
      return
    }

    // Observe effective appearance changes
    appearanceObserver = self.observe(\.effectiveAppearance, options: [.new, .old]) { [weak self] _, _ in
      guard let self else {
        return
      }
      self.scheduleThemeUpdate(self.theme)
    }
  }

  private func cancelObservingAppearance() {
    appearanceObserver?.invalidate()
    appearanceObserver = nil
  }
  #endif

  #if canImport(UIKit)
  /// The theme of the view.
  public var theme: Theme {
    let getThemeFromTraitCollection: () -> Theme = {
      switch self.traitCollection.userInterfaceStyle {
      case .unspecified:
        #if !os(tvOS)
        ComposeUI.assertFailure("unspecified traitCollection.userInterfaceStyle")
        #endif
        return .light
      case .light:
        return .light
      case .dark:
        return .dark
      @unknown default:
        ComposeUI.assertFailure("unknown UIUserInterfaceStyle: \(self.traitCollection.userInterfaceStyle)")
        return .light
      }
    }

    switch overrideUserInterfaceStyle {
    case .unspecified:
      return getThemeFromTraitCollection()
    case .light:
      return .light
    case .dark:
      return .dark
    @unknown default:
      ComposeUI.assertFailure("unknown overrideUserInterfaceStyle: \(overrideUserInterfaceStyle)")
      return getThemeFromTraitCollection()
    }
  }

  /// The override theme of the view.
  public var overrideTheme: Theme? {
    get {
      overrideUserInterfaceStyle.theme
    }
    set {
      if let newValue {
        overrideUserInterfaceStyle = newValue.isLight ? .light : .dark
      } else {
        overrideUserInterfaceStyle = .unspecified
      }
    }
  }

  override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    scheduleThemeUpdate(theme)
  }
  #endif
}
