//
//  RenderEventCounter.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

@testable import ComposeUI

/// Counts a compose view's render work through its debug events: the render passes, the renderable items they make,
/// and the renderables they insert, reuse and remove.
final class RenderEventCounter {

  private(set) var renderPasses = 0

  private(set) var renderableItems = 0

  private(set) var inserts = 0

  private(set) var reuses = 0

  private(set) var removals = 0

  /// Starts counting the view's render events. Replaces the view's debug event handler.
  ///
  /// - Parameter view: The view to count the render events of.
  init(view: ComposeView) {
    view.debug { [weak self] _, event in
      guard let self else {
        return
      }

      switch event {
      case .renderWillBegin:
        renderPasses += 1
      case .renderDidReceiveRenderableItems(let renderableItems, _):
        self.renderableItems += renderableItems.count
      case .renderWillInsertRenderable:
        inserts += 1
      case .renderWillReuseRenderable:
        reuses += 1
      case .renderWillRemoveRenderable:
        removals += 1
      default:
        break
      }
    }
  }
}
