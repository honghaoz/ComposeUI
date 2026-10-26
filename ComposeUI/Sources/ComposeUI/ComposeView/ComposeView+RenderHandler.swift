//
//  ComposeView+RenderHandler.swift
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

import Foundation

public extension ComposeView {

  /// The type of the render pass.
  enum RenderType: Equatable {

    /// The content is refreshed by an explicit refresh request or in response to an environment change.
    case refresh(isAnimated: Bool)

    /// The viewport is changed by scrolling, resizing, or both.
    ///
    /// - Parameters:
    ///   - previousBounds: The viewport from the last completed render, or nil before the first render.
    ///   - bounds: The viewport when this render type is reported, without applying `visibleBoundsInsets`.
    ///     The will-layout handler receives the proposed layout viewport, the will-render handler receives the viewport
    ///     after the layout, when the content size was applied, and the `AnimationBehavior.dynamic` closure and the
    ///     did-render handler receive the viewport after the will-render handler ran.
    case boundsChange(previousBounds: CGRect?, bounds: CGRect)
  }

  /// The context for the will-layout handler.
  struct WillLayoutContext {

    /// The container size that will be used for layout: the visible size minus the content insets (`adjustedContentInset`).
    public let containerSize: CGSize

    /// The render type for this render pass.
    public let renderType: RenderType
  }

  /// The context for the will-render handler.
  struct WillRenderContext {

    /// The content size after layout.
    ///
    /// If the `content`'s natural size is smaller than the layout container size (`WillLayoutContext.containerSize`) in either dimension, the content size is adjusted to be the same as the container size.
    public let contentSize: CGSize

    /// The `ComposeView`'s bounds that will be used for rendering.
    ///
    /// The bounds' size is the visible size, while the content lays out in that size minus the content insets
    /// (`WillLayoutContext.containerSize`).
    ///
    /// Not to be confused with `ComposeNode.renderBounds`, which is the area that a node's renderable items cover.
    public let renderBounds: CGRect

    /// The render type for this render pass.
    public let renderType: RenderType
  }

  /// The context for the did-render handler.
  struct DidRenderContext {

    /// The content size after the render pass.
    public let contentSize: CGSize

    /// The `ComposeView`'s bounds used for rendering.
    ///
    /// The bounds' size is the visible size, while the content lays out in that size minus the content insets
    /// (`WillLayoutContext.containerSize`).
    ///
    /// Not to be confused with `ComposeNode.renderBounds`, which is the area that a node's renderable items cover.
    public let renderBounds: CGRect

    /// The render type for this render pass.
    public let renderType: RenderType
  }
}
