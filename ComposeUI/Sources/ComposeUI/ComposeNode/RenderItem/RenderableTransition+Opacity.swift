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
  /// - Parameters:
  ///   - from: The starting opacity value.
  ///   - to: The ending opacity value.
  ///   - timing: The timing function for the animation.
  ///   - options: The options for the transition.
  static func opacity(from: CGFloat = 0,
                      to: CGFloat = 1,
                      timing: AnimationTiming = .easeInEaseOut(duration: Animations.defaultAnimationDuration),
                      options: RenderableTransition.Options = .both) -> RenderableTransition
  {
    RenderableTransition(
      insert: options.contains(.insert) ? InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)

        let layer = renderable.layer

        layer.opacity = Float(from)
        layer.animate(
          keyPath: "opacity",
          timing: timing,
          from: { _ in Float(from - to) },
          to: { _ in 0 },
          model: { _ in Float(to) },
          updateAnimation: {
            $0.isAdditive = true
            $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
              completion()
            })
          }
        )
      } : nil,
      remove: options.contains(.remove) ? RemoveTransition { renderable, context, completion in
        renderable.layer.animate(
          keyPath: "opacity",
          timing: timing,
          from: { $0.opacity - Float(from) },
          to: { _ in 0 },
          model: { _ in Float(from) },
          updateAnimation: {
            $0.isAdditive = true
            $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
              completion()
            })
          }
        )
      } : nil
    )
  }
}
