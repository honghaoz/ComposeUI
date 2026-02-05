//
//  BaseScrollViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/24/25.
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

import ChouTiTest

import Combine
import ComposeUI

class BaseScrollViewTests: XCTestCase {

  // MARK: - Theme

  func test_theme() throws {
    let scrollView = BaseScrollView()
    let initialTheme = scrollView.theme

    // set the override theme to the opposite of the initial theme
    let overrideTheme: Theme
    switch initialTheme {
    case .light:
      overrideTheme = .dark
    case .dark:
      overrideTheme = .light
    }

    scrollView.overrideTheme = overrideTheme
    expect(scrollView.theme) == overrideTheme
  }

  func test_theme_standaloneView() {
    let currentTheme = ThemingTest.currentTheme
    let view = BaseScrollView()

    expect(view.theme) == currentTheme
    expect(view.overrideTheme) == nil

    view.overrideTheme = .dark
    expect(view.theme) == .dark
    expect(view.overrideTheme) == .dark

    view.overrideTheme = nil
    #if os(macOS)
    expect(view.theme) == .dark // expected to be currentTheme, but it returns the last override theme
    #else
    expect(view.theme) == currentTheme
    #endif
    expect(view.overrideTheme) == nil

    view.overrideTheme = .light
    expect(view.theme) == .light
    expect(view.overrideTheme) == .light

    view.overrideTheme = nil
    #if os(macOS)
    expect(view.theme) == .light // expected to be currentTheme, but it returns the last override theme
    #else
    expect(view.theme) == currentTheme
    #endif
    expect(view.overrideTheme) == nil
  }

  func test_theme_viewInWindow() {
    let currentTheme = ThemingTest.currentTheme

    let window = TestWindow()
    let view = BaseScrollView()
    window.contentView().addSubview(view)

    expect(view.theme) == currentTheme
    expect(view.overrideTheme) == nil

    view.overrideTheme = .dark
    expect(view.theme) == .dark
    expect(view.overrideTheme) == .dark

    view.overrideTheme = nil
    expect(view.theme) == currentTheme
    expect(view.overrideTheme) == nil

    view.overrideTheme = .light
    expect(view.theme) == .light
    expect(view.overrideTheme) == .light

    view.overrideTheme = nil
    expect(view.theme) == currentTheme
    expect(view.overrideTheme) == nil
  }

  /// Test that view in view hierarchy should follow the parent view's theme.
  func test_theme_viewInViewHierarchy() {
    let currentTheme = ThemingTest.currentTheme

    // given a container view in a window
    let window = TestWindow()
    let containerView = BaseScrollView()
    window.contentView().addSubview(containerView)
    expect(containerView.theme) == currentTheme
    expect(containerView.overrideTheme) == nil

    // given a child view in the container view
    let childView1 = BaseScrollView()
    containerView.addSubview(childView1)

    // then the child view's theme should be the same as the container view's theme
    expect(childView1.theme) == currentTheme
    expect(childView1.overrideTheme) == nil

    containerView.overrideTheme = .dark
    expectTheme(of: childView1, toBe: .dark)
    expect(childView1.overrideTheme) == nil

    containerView.overrideTheme = nil
    expectTheme(of: childView1, toBe: currentTheme)
    expect(childView1.theme) == currentTheme
    expect(childView1.overrideTheme) == nil

    containerView.overrideTheme = .light
    expectTheme(of: childView1, toBe: .light)
    expect(childView1.overrideTheme) == nil

    containerView.overrideTheme = nil
    expectTheme(of: childView1, toBe: currentTheme)
    expect(childView1.theme) == currentTheme
    expect(childView1.overrideTheme) == nil

    // when set the container view's override theme to the opposite of the current theme
    containerView.overrideTheme = currentTheme.opposite
    expect(containerView.theme) == currentTheme.opposite
    expect(containerView.overrideTheme) == currentTheme.opposite

    // given a new child view
    let childView2 = BaseScrollView()

    // when it is a standalone view, it should follow the current theme
    expect(childView2.theme) == currentTheme
    expect(childView2.overrideTheme) == nil

    // when it is added to the container view, it should follow the container view's theme
    containerView.addSubview(childView2)
    expectTheme(of: childView2, toBe: currentTheme.opposite)
    expect(childView2.overrideTheme) == nil

    // when the child view is removed from the container view, it should keep the same theme as before
    childView2.removeFromSuperview()
    expectTheme(of: childView2, toBe: currentTheme.opposite)
    expect(childView2.overrideTheme) == nil

    // given a new nested child view
    let childView3 = BaseScrollView()
    let childView4 = BaseScrollView()
    childView3.addSubview(childView4)

    // when it is a standalone view, it should follow the current theme
    expect(childView3.theme) == currentTheme
    expect(childView3.overrideTheme) == nil
    expect(childView4.theme) == currentTheme
    expect(childView4.overrideTheme) == nil

    // when they are added to the container view, they should follow the container view's theme
    containerView.addSubview(childView3)
    expectTheme(of: childView3, toBe: currentTheme.opposite)
    expect(childView3.overrideTheme) == nil
    expectTheme(of: childView4, toBe: currentTheme.opposite)
    expect(childView4.overrideTheme) == nil
  }

  // MARK: - Edge Cases

  func test_theme_onBackgroundThread() {
    let currentTheme = ThemingTest.currentTheme

    let expectation = XCTestExpectation(description: "theme")

    let view = BaseScrollView()

    DispatchQueue.global().async {
      expect(view.theme) == currentTheme
      expect(view.overrideTheme) == nil

      view.overrideTheme = .dark
      expect(view.theme) == .dark
      expect(view.overrideTheme) == .dark

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1)
  }

  // MARK: - Theme Publisher

  func test_themePublisher() throws {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    #if canImport(AppKit)
    let window = TestWindow()
    window.setFrame(frame, display: false)
    window.appearance = NSAppearance(named: .darkAqua)
    let scrollView = BaseScrollView()
    window.contentView?.addSubview(scrollView)
    scrollView.frame = frame
    #endif

    #if canImport(UIKit)
    let window = TestWindow()
    window.overrideUserInterfaceStyle = .dark
    window.frame = frame
    let scrollView = BaseScrollView()
    window.addSubview(scrollView)
    scrollView.frame = window.bounds
    #endif

    // flush the run loop to make sure the theme is set
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    let initialTheme = scrollView.theme

    let overrideTheme: Theme
    switch initialTheme {
    case .light:
      overrideTheme = .dark
    case .dark:
      overrideTheme = .light
    }

    let expectation1 = expectation(description: "themePublisher should emit the override theme")
    let expectation2 = expectation(description: "themePublisher should emit the initial theme")
    let expectation3 = expectation(description: "themePublisher should emit the new theme")

    var callCount = 0
    let cancellable = scrollView.themePublisher.sink { theme in
      switch callCount {
      case 0:
        expect(theme) == initialTheme // the initial emission
      case 1:
        expect(theme) == overrideTheme // the override theme
        expectation1.fulfill()
      case 2:
        expect(theme) == initialTheme // remove the override theme
        expectation2.fulfill()
      case 3:
        expect(theme) == .light // moved to the new window
        expectation3.fulfill()
      default:
        fail("excessive emissions")
      }
      callCount += 1
    }
    _ = cancellable

    scrollView.overrideTheme = overrideTheme

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    scrollView.overrideTheme = nil

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    #if canImport(AppKit)
    let window2 = TestWindow()
    window2.setFrame(frame, display: false)
    window2.appearance = NSAppearance(named: .aqua)
    window2.contentView?.addSubview(scrollView)
    #endif

    #if canImport(UIKit)
    let window2 = TestWindow()
    window2.overrideUserInterfaceStyle = .light
    window2.frame = frame
    window2.addSubview(scrollView)
    #endif

    waitForExpectations(timeout: 1)
  }

  // MARK: - Helper

  /// Expect the theme of a view to be the given theme.
  private func expectTheme(of view: BaseScrollView, toBe expectedTheme: Theme, line: UInt = #line) {
    #if os(macOS)
    expect(view.theme, line: line) == expectedTheme // macOS theme update happens immediately
    #else
    expect(view.theme, line: line).toEventually(beEqual(to: expectedTheme)) // UIKit theme update happens on next runloop
    #endif
  }
}

private enum ThemingTest {

  /// Get the current theme, this is based on the current system theme.
  static var currentTheme: Theme {
    #if os(macOS)
    return NSApplication.shared.effectiveAppearance.theme // current macOS system theme
    #else
    return UITraitCollection.current.userInterfaceStyle.theme // current iOS/tvOS/visionOS system theme
    #endif
  }
}

private extension Theme {

  /// Returns the opposite theme.
  var opposite: Theme {
    switch self {
    case .light:
      return .dark
    case .dark:
      return .light
    }
  }
}
