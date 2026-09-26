//
//  RenderableTransition+Opacity.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/18/24.
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

import QuartzCore

public extension RenderableTransition {

  /// Creates an opacity transition.
  ///
  /// For insertion, the renderable fades from `from` to `to`, or when `to` is `nil`, to the opacity its content sets.
  /// For removal, the renderable fades from its current opacity back to `from`.
  /// Starting a transition while another one is in flight continues from the current visual opacity.
  ///
  /// - Parameters:
  ///   - from: The starting opacity value.
  ///   - to: The ending opacity value. `nil`, the default, ends at the opacity the content sets.
  ///   - timing: The timing function for the animation.
  ///   - options: The options for the transition.
  static func opacity(from: CGFloat = 0,
                      to: CGFloat? = nil,
                      timing: AnimationTiming = .easeInEaseOut(duration: Animations.defaultAnimationDuration),
                      options: RenderableTransition.Options = .both) -> RenderableTransition
  {
    RenderableTransition(
      insert: options.contains(.insert) ? InsertTransition(
        takesOverKeyPaths: ["opacity"],
        prepareForTakeover: to == nil ? { renderable in
          // the removal's opacity isn't the content's, so it's replaced with the fresh 1, keeping what's shown
          renderable.layer.retargetOpacity(to: 1)
        } : nil,
        animate: { renderable, context, completion in
          renderable.setFrame(context.targetFrame)

          let layer = renderable.layer
          let targetValue = to.map { Float($0) } ?? layer.opacity
          layer.animateOpacity(to: targetValue, timing: timing, freshStartValue: Float(from), completion: completion)
        }
      ) : nil,
      remove: options.contains(.remove) ? RemoveTransition(
        animatedKeyPaths: ["opacity"],
        animate: { renderable, _, completion in
          let layer = renderable.layer
          layer.animateOpacity(to: Float(from), timing: timing, freshStartValue: layer.opacity, completion: completion)
        },
        resetForReuse: { renderable in
          renderable.layer.setKeyPathValue("opacity", Float(1))
        }
      ) : nil
    )
  }
}
