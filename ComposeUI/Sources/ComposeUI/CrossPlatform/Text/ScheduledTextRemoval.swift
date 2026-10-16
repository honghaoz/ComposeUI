//
//  ScheduledTextRemoval.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/15/26.
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

import Foundation

/// A view that shows a text node's text, and keeps the text that a reset for a reuse by a text node leaves, until the
/// end of the run loop turn.
protocol ScheduledTextRemovable: AnyObject {

  /// Whether the view removes its text at the end of the run loop turn, unless it gets another text before.
  var isTextRemovalScheduled: Bool { get set }

  /// Whether the view is in the list of views that remove their text at the end of the run loop turn, where it stays
  /// until then, also when another text cancels the removal.
  var isInTextRemovalList: Bool { get set }

  /// Removes the text that a reset for a reuse by a text node kept.
  func removeTextForReuse()
}

/// The views that remove their text at the end of the run loop turn, unless they get another text before.
///
/// A view that a text node resets for reuse keeps its text until then, so that a reuse in the same render pass replaces
/// the text in one edit, while a view that stays in the pool doesn't keep its text for longer than the turn, nor the
/// objects that the text's attributes hold, except a UIKit text view, which keeps them until it gets another text. The
/// list holds each view once, so that it stays as long as the number of views reset in the turn, however many refreshes
/// run in it.
///
/// The list holds its views strongly, which keeps one that the pool has no room for until the end of the turn: AppKit
/// keeps a text view that its owners let go of alive for longer than that anyway.
enum ScheduledTextRemoval {

  /// The views that remove their text at the end of the run loop turn.
  private static var views: [any ScheduledTextRemovable] = []

  #if DEBUG
  /// The number of views in the list.
  static var count: Int {
    views.count
  }
  #endif

  /// Schedules a view to remove its text at the end of the run loop turn, unless it gets another text before.
  static func schedule(_ view: any ScheduledTextRemovable) {
    view.isTextRemovalScheduled = true

    // a view that's reused and reset again in the same turn is in the list already
    guard !view.isInTextRemovalList else {
      return
    }

    if views.isEmpty {
      onNextRunLoop {
        removeTexts()
      }
    }
    view.isInTextRemovalList = true
    views.append(view)
  }

  /// Removes the text of each listed view that hasn't got another text.
  private static func removeTexts() {
    // a text storage edit can call back into code that resets views, which then schedule into a new list, so the list is
    // taken first instead of cleared after the loop
    let views = views
    Self.views = []
    for view in views {
      view.isInTextRemovalList = false
      if view.isTextRemovalScheduled {
        view.removeTextForReuse()
      }
    }
  }
}
