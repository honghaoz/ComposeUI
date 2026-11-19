//
//  ReadmeDemo01QuickStart.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/18/26.
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

import ComposeUI

/// The README "Quick start" demo: a counter that refreshes on a state change.
class CounterView: ComposeView {

  var count = 0

  @ComposeContentBuilder
  override var content: ComposeContent {
    Label("Count: \(count)")
      .font(.boldSystemFont(ofSize: 24))
  }

  func increment() {
    count += 1
    refresh()
  }
}

/// The README "Quick start" examples that make a `ComposeView` without a subclass.
enum QuickStartExamples {

  /// Makes a view with a content closure, which reads the state on each refresh.
  static func contentClosure() {
    var count = 0
    let view = ComposeView {
      Label("Count: \(count)")
        .font(.boldSystemFont(ofSize: 24))
    }

    count += 1
    view.refresh()
  }

  /// Sets the content of an existing view.
  static func setContent() {
    let view = ComposeView()
    view.setContent {
      Label("Hello, ComposéUI")
    }
  }
}
