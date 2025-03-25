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
@testable import ComposeUI

class BaseScrollViewTests: XCTestCase {

  // func test_theme() {
  //   let scrollView = BaseScrollView()
  //   let initialTheme = scrollView.theme

  //   // set the override theme to the opposite of the initial theme
  //   let overrideTheme: Theme
  //   switch initialTheme {
  //   case .light:
  //     overrideTheme = .dark
  //   case .dark:
  //     overrideTheme = .light
  //   }

  //   scrollView.overrideTheme = overrideTheme
  //   expect(scrollView.theme) == overrideTheme
  // }

  // func test_themePublisher() {
  //   if ProcessInfo.isRunningInGitHubActions {
  //     print("Skipping test_themePublisher in GitHub Actions environment")
  //     return
  //   }

  //   let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

  //   #if canImport(AppKit)
  //   let window = NSWindow(contentRect: frame, styleMask: [], backing: .buffered, defer: false)
  //   window.appearance = NSAppearance(named: .darkAqua)
  //   let scrollView = BaseScrollView()
  //   window.contentView?.addSubview(scrollView)
  //   scrollView.frame = frame
  //   #endif

  //   #if canImport(UIKit)
  //   let window = UIWindow()
  //   window.overrideUserInterfaceStyle = .dark
  //   window.frame = frame
  //   let scrollView = BaseScrollView()
  //   window.addSubview(scrollView)
  //   scrollView.frame = window.bounds
  //   #endif

  //   // flush the run loop to make sure the theme is set
  //   RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

  //   let initialTheme = scrollView.theme

  //   let overrideTheme: Theme
  //   switch initialTheme {
  //   case .light:
  //     overrideTheme = .dark
  //   case .dark:
  //     overrideTheme = .light
  //   }

  //   let expectation1 = expectation(description: "themePublisher should emit the override theme")
  //   let expectation2 = expectation(description: "themePublisher should emit the initial theme")
  //   let expectation3 = expectation(description: "themePublisher should emit the new theme")

  //   var callCount = 0
  //   let cancellable = scrollView.themePublisher.sink { theme in
  //     switch callCount {
  //     case 0:
  //       expect(theme) == initialTheme // the initial emission
  //     case 1:
  //       expect(theme) == overrideTheme // the override theme
  //       expectation1.fulfill()
  //     case 2:
  //       expect(theme) == initialTheme // remove the override theme
  //       expectation2.fulfill()
  //     case 3:
  //       expect(theme) == .light // moved to the new window
  //       expectation3.fulfill()
  //     default:
  //       fail("excessive emissions")
  //     }
  //     callCount += 1
  //   }
  //   _ = cancellable

  //   scrollView.overrideTheme = overrideTheme

  //   RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

  //   scrollView.overrideTheme = nil

  //   RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

  //   #if canImport(AppKit)
  //   let window2 = NSWindow(contentRect: frame, styleMask: [], backing: .buffered, defer: false)
  //   window2.appearance = NSAppearance(named: .aqua)
  //   window2.contentView?.addSubview(scrollView)
  //   #endif

  //   #if canImport(UIKit)
  //   let window2 = UIWindow()
  //   window2.overrideUserInterfaceStyle = .light
  //   window2.frame = frame
  //   window2.addSubview(scrollView)
  //   #endif

  //   waitForExpectations(timeout: 1)
  // }
}
