//
//  TextLayoutRecorder.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/19/26.
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

/// Records the layouts that a layout manager completes, and the edits to its text storage.
final class TextLayoutRecorder: NSObject, NSLayoutManagerDelegate {

  /// A completed layout: the text that laid out, and the width of the container that it laid out in.
  struct Layout: Equatable {

    let text: String

    let width: CGFloat
  }

  /// The layouts of a text with characters in a container, in order. An empty text has nothing to draw, and a call
  /// without a container only tells that the text goes past the containers, after the call for the filled container, so
  /// neither is recorded.
  private(set) var layouts: [Layout] = []

  /// The number of edits to the text storage.
  private(set) var editCount = 0

  private var observer: NSObjectProtocol?

  /// Starts recording a layout manager's layouts and its text storage's edits. Replaces the layout manager's delegate.
  ///
  /// - Parameter layoutManager: The layout manager to record.
  init(_ layoutManager: NSLayoutManager) {
    super.init()
    layoutManager.delegate = self
    observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: layoutManager.textStorage, queue: nil) { [weak self] _ in
      self?.editCount += 1
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
    guard let textContainer, let text = layoutManager.textStorage?.string, !text.isEmpty else {
      return
    }
    layouts.append(Layout(text: text, width: textContainer.size.width))
  }
}
