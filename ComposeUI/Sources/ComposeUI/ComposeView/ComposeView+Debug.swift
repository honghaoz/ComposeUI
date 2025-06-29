//
//  ComposeView+Debug.swift
//  ComposéUI
//
//  Created by Honghao on 6/28/25.
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

#if DEBUG
import Foundation

public extension ComposeView {

  /// A debug tool to inject event handlers into the ComposeView.
  final class Debug {

    public enum Event {
      case renderWillLayout(contentNode: ComposeNode, bounds: CGRect, visibleBounds: CGRect)
      case renderDidLayout(contentSize: CGSize)
      case renderWillRender(visibleBounds: CGRect)
      case renderDidRender(renderableItems: [RenderableItem], contentSize: CGSize)
      case renderDidUpdateScrollableBehavior(isScrollable: Bool, alwaysBounceHorizontal: Bool, alwaysBounceVertical: Bool)
      case renderDidUpdateClippingBehavior(clipsToBounds: Bool)
      case renderDidUpdateScrollIndicatorBehavior(showsHorizontalScrollIndicator: Bool, showsVerticalScrollIndicator: Bool)
      case renderWillRemoveRenderable(item: RenderableItem, renderable: Renderable)
      case renderDidRemoveRenderable(item: RenderableItem, renderable: Renderable)
      case renderDidCancelRemoveRenderable(item: RenderableItem, renderable: Renderable)
      case renderWillReuseRenderable(item: RenderableItem, renderable: Renderable)
      case renderDidReuseRenderable(item: RenderableItem, renderable: Renderable)
      case renderWillInsertRenderable(item: RenderableItem, renderable: Renderable)
      case renderDidInsertRenderable(item: RenderableItem, renderable: Renderable)
      case renderDidFinish(renderableItemIds: [String], renderableItemMap: [String: RenderableItem], renderableMap: [String: Renderable])
    }

    private weak var composeView: ComposeView?
    private let eventHandler: (ComposeView, ComposeView.Debug.Event) -> Void

    init(composeView: ComposeView, eventHandler: @escaping (ComposeView, ComposeView.Debug.Event) -> Void) {
      self.composeView = composeView
      self.eventHandler = eventHandler
    }

    func onEvent(_ event: ComposeView.Debug.Event) {
      guard let composeView else {
        return
      }
      eventHandler(composeView, event)
    }
  }
}
#endif
