//
//  ComposeView+AnimationDecision.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/14/26.
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

  /// The transition and update animation decisions for one render pass.
  struct AnimationDecision: Equatable {

    /// Transitions and update animations run.
    static let all = AnimationDecision(allowsTransitions: true, allowsAnimations: true)

    /// Neither transitions nor update animations run.
    static let disabled = AnimationDecision(allowsTransitions: false, allowsAnimations: false)

    /// Transitions run while reused renderables update immediately.
    static let transitionsOnly = AnimationDecision(allowsTransitions: true, allowsAnimations: false)

    /// Whether inserted and removed renderables run their configured transitions.
    let allowsTransitions: Bool

    /// Whether reused renderables use their configured update animations.
    let allowsAnimations: Bool

    /// The decision limited by a parent's decision.
    ///
    /// A view rendering its parent's prepared content can lower the parent's decision with its own animation behavior but
    /// must not raise it, so nested content never animates more than the parent's render pass.
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

extension ComposeView.AnimationBehavior {

  /// Resolves the transition and update animation decision of this behavior once for the render pass.
  ///
  /// - Parameters:
  ///   - renderType: The render type with the pass's final render bounds.
  ///   - contentView: The content view performing the render pass.
  /// - Returns: The animation types this behavior allows for the render pass.
  func animationDecision(renderType: ComposeView.RenderType, contentView: ComposeView) -> ComposeView.AnimationDecision {
    switch self {
    case .default:
      switch renderType {
      case .refresh(let isAnimated):
        return isAnimated ? .all : .disabled
      case .boundsChange:
        return .transitionsOnly
      }
    case .disabled:
      return .disabled
    case .dynamic(let shouldAnimate):
      return shouldAnimate(contentView, renderType) ? .all : .disabled
    }
  }
}
