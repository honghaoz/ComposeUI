//
//  ComposeView+LockedScrollViewSettings.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/23/26.
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

public extension ComposeView {

  /// Always `false`, so the content insets stay the same under the window's title bar and toolbar.
  ///
  /// Setting it to `true` asserts and keeps it `false`.
  override final var automaticallyAdjustsContentInsets: Bool {
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
  override final var allowsMagnification: Bool {
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
  override final var magnification: CGFloat {
    get {
      super.magnification
    }
    set {
      ComposeUI.assert(newValue == 1, "ComposeView doesn't support magnification")
    }
  }

  /// Keeps the magnification at 1, since `ComposeView` doesn't support magnification. Another magnification asserts.
  override final func setMagnification(_ magnification: CGFloat, centeredAt point: CGPoint) {
    ComposeUI.assert(magnification == 1, "ComposeView doesn't support magnification")
  }

  /// Keeps the magnification at 1 and asserts, since `ComposeView` doesn't support magnification.
  override final func magnify(toFit rect: CGRect) {
    ComposeUI.assertFailure("ComposeView doesn't support magnification")
  }

  /// Always 1, since `ComposeView` doesn't support magnification.
  ///
  /// Setting another value asserts and keeps 1.
  override final var minMagnification: CGFloat {
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
  override final var maxMagnification: CGFloat {
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
  override final var borderType: NSBorderType {
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
  override final var autohidesScrollers: Bool {
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
  override final var rulersVisible: Bool {
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
  override final var isFindBarVisible: Bool {
    get {
      super.isFindBarVisible
    }
    set {
      // AppKit makes room for the find bar in the insets it scrolls with, which the scroll bar decision doesn't count, so
      // content overflowing only below the find bar would get no scroll bar
      ComposeUI.assert(!newValue, "ComposeView doesn't support the find bar")
    }
  }
}
#endif
