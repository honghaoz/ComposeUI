//
//  ComposeView+ContentUpdateContext.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

extension ComposeView {

  /// The content and bounds used for one update.
  struct ContentUpdateContext: Equatable {

    /// The type of the content update.
    enum ContentUpdateType: Equatable {

      /// An application-requested or environment-triggered refresh with its animation preference.
      case refresh(isAnimated: Bool)

      /// A bounds update using retained content.
      case boundsChange
    }

    /// The root layout node used for this update.
    let contentNode: LayoutCacheNode

    /// The content evaluation used for this update.
    let contentEvaluation: ContentEvaluation

    /// The content update type.
    let updateType: ContentUpdateType

    /// The bounds from the last completed render pass, or nil before the first render.
    let previousRenderBounds: CGRect?

    /// The viewport bounds proposed for this pass's layout.
    let renderBounds: CGRect

    /// The parent's decisions when this pass applies prepared content.
    let inheritedAnimationDecision: AnimationDecision?

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.contentNode === rhs.contentNode &&
        lhs.contentEvaluation === rhs.contentEvaluation &&
        lhs.updateType == rhs.updateType &&
        lhs.previousRenderBounds == rhs.previousRenderBounds &&
        lhs.renderBounds == rhs.renderBounds &&
        lhs.inheritedAnimationDecision == rhs.inheritedAnimationDecision
    }

    // MARK: - Render Type

    /// The render type describes the update using the viewport available at the current callback phase.
    ///
    /// - Parameter bounds: The viewport used by the callback, without applying `visibleBoundsInsets`.
    func renderType(bounds: CGRect) -> RenderType {
      switch updateType {
      case .refresh(let isAnimated):
        return .refresh(isAnimated: isAnimated)
      case .boundsChange:
        return .boundsChange(previousBounds: previousRenderBounds, bounds: bounds)
      }
    }
  }
}
