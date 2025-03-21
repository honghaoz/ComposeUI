//
//  ScrollViewType.swift
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

/// A type that represents a cross-platform scroll view.
protocol ScrollViewType: ScrollView {

  /// The bounds of the scroll view.
  func bounds() -> CGRect

  /// The content size of the scroll view.
  func contentSize() -> CGSize

  /// Set the content size of the scroll view.
  func setContentSize(_ size: CGSize)

  /// The view you should add your subviews to.
  func contentView() -> View

  /// A boolean value that determines whether bouncing always occurs when vertical scrolling reaches the end of the content.
  var alwaysBounceVertical: Bool { get set }

  /// A boolean value that determines whether bouncing always occurs when horizontal scrolling reaches the end of the content view.
  var alwaysBounceHorizontal: Bool { get set }
}

extension ScrollView: ScrollViewType {}

extension ScrollViewType {

  func bounds() -> CGRect {
    #if canImport(AppKit)
    return contentView.bounds
    #endif

    #if canImport(UIKit)
    return self.bounds
    #endif
  }

  func contentSize() -> CGSize {
    #if canImport(AppKit)
    return contentView().bounds.size
    #endif

    #if canImport(UIKit)
    return self.contentSize
    #endif
  }

  func setContentSize(_ size: CGSize) {
    #if canImport(AppKit)
    guard let documentView = documentView else {
      assertionFailure("NSScrollView has no document view. Please set `documentView`.")
      return
    }
    assert(documentView.frame.origin == .zero)
    documentView.frame = CGRect(origin: .zero, size: size)
    #endif

    #if canImport(UIKit)
    self.contentSize = size
    #endif
  }

  func contentView() -> View {
    #if canImport(AppKit)
    guard let documentView = documentView else {
      assertionFailure("NSScrollView has no document view. Please set `documentView`.")
      return self
    }
    return documentView
    #endif

    #if canImport(UIKit)
    return self
    #endif
  }
}
