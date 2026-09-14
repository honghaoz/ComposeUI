//
//  ComposeView+AnimationBehavior.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/13/26.
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

  /// The animation behavior of the ComposeView's content update.
  enum AnimationBehavior {

    /// The default animation behavior.
    ///
    /// - Refreshes (`refresh(animated:)` and `setNeedsRefresh(animated:)`): Transitions and animations follow their `animated` flag.
    /// - Bounds change (resize or scroll): Transitions are enabled, but animations are disabled.
    case `default`

    /// The transitions and animations are disabled.
    case disabled

    /// The dynamic animation behavior.
    ///
    /// The closure is called once per render pass and determines whether the transitions and animations are enabled.
    ///
    /// Note: For render type `boundsChange`, returning `true` will also animate the reused renderables' updates, so
    /// their frame can lag behind scrolling and live resizing.
    case dynamic(_ shouldAnimate: (_ contentView: ComposeView, _ renderType: RenderType) -> Bool)

    /// Resolves the transition and update animation decision of this behavior once for the render pass.
    ///
    /// - Parameters:
    ///   - renderType: The render type with the pass's final render bounds.
    ///   - contentView: The content view performing the pass.
    /// - Returns: The animation types this behavior allows for the pass.
    func animationDecision(renderType: ComposeView.RenderType, contentView: ComposeView) -> ComposeView.AnimationDecision {
      switch self {
      case .default:
        switch renderType {
        case .refresh(let isAnimated):
          return ComposeView.AnimationDecision(allowsTransitions: isAnimated, allowsAnimations: isAnimated)
        case .boundsChange:
          return ComposeView.AnimationDecision(allowsTransitions: true, allowsAnimations: false)
        }
      case .disabled:
        return ComposeView.AnimationDecision(allowsTransitions: false, allowsAnimations: false)
      case .dynamic(let shouldAnimate):
        let isAnimated = shouldAnimate(contentView, renderType)
        return ComposeView.AnimationDecision(allowsTransitions: isAnimated, allowsAnimations: isAnimated)
      }
    }
  }
}

extension ComposeView {

  /// The transition and update animation decisions for one render pass.
  struct AnimationDecision: Equatable {

    /// Whether inserted and removed renderables run their configured transitions.
    let allowsTransitions: Bool

    /// Whether reused renderables use their configured update animations.
    let allowsAnimations: Bool

    /// The decision limited by a parent's decision.
    ///
    /// A view rendering its parent's prepared content can lower the parent's decision with its own animation behavior but
    /// must not raise it, so nested content never animates more than the parent's pass.
    ///
    /// - Parameter parent: The decision of the parent's render pass.
    /// - Returns: A decision allowing each animation type only if both decisions allow it.
    func capped(by parent: AnimationDecision) -> AnimationDecision {
      AnimationDecision(
        allowsTransitions: allowsTransitions && parent.allowsTransitions,
        allowsAnimations: allowsAnimations && parent.allowsAnimations
      )
    }
  }
}
