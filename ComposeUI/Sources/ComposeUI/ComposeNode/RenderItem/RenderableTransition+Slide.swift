//
//  RenderableTransition+Slide.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/23/24.
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

  /// The side of the slide transition.
  enum SlideSide {

    case top
    case bottom
    case left
    case right
  }

  /// Creates a slide transition.
  ///
  /// - Parameters:
  ///   - from: The side of the slide transition to slide from.
  ///   - to: The side of the slide transition to slide to.
  ///   - overshoot: The amount of overshoot for the slide transition. Defaults to 8.
  ///   - timing: The timing of the slide transition.
  ///   - options: The options for the slide transition.
  static func slide(from fromSide: SlideSide,
                    to toSide: SlideSide? = nil,
                    overshoot: CGFloat = 8,
                    timing: AnimationTiming = .spring(),
                    options: RenderableTransition.Options = .both) -> Self
  {
    RenderableTransition(
      insert: options.contains(.insert) ? InsertTransition { renderable, context, completion in
        let layer = renderable.layer
        let targetFrame = context.targetFrame

        let initialFrame: CGRect
        switch fromSide {
        case .top:
          initialFrame = targetFrame.translate(dy: -targetFrame.maxY - overshoot)
        case .bottom:
          initialFrame = targetFrame.translate(dy: context.contentView.bounds.height - targetFrame.minY + overshoot)
        case .left:
          initialFrame = targetFrame.translate(dx: -targetFrame.maxX - overshoot)
        case .right:
          initialFrame = targetFrame.translate(dx: context.contentView.bounds.width - targetFrame.minX + overshoot)
        }
        renderable.setFrame(initialFrame)

        layer.animate(
          keyPath: "position",
          timing: timing,
          from: { $0.position(from: $0.frame) - $0.position(from: targetFrame) },
          to: { _ in .zero },
          model: { $0.position(from: targetFrame) },
          updateAnimation: {
            $0.isAdditive = true
            $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
              completion()
            })
          }
        )
      } : nil,
      remove: options.contains(.remove) ? RemoveTransition { renderable, context, completion in
        let layer = renderable.layer
        let currentFrame = layer.frame

        let targetFrame: CGRect
        switch fromSide {
        case .top:
          targetFrame = currentFrame.translate(dy: -currentFrame.maxY - overshoot)
        case .bottom:
          targetFrame = currentFrame.translate(dy: context.contentView.bounds.height - currentFrame.minY + overshoot)
        case .left:
          targetFrame = currentFrame.translate(dx: -currentFrame.maxX - overshoot)
        case .right:
          targetFrame = currentFrame.translate(dx: context.contentView.bounds.width - currentFrame.minX + overshoot)
        }

        layer.animate(
          keyPath: "position",
          timing: timing,
          from: { $0.position(from: $0.frame) - $0.position(from: targetFrame) },
          to: { _ in .zero },
          model: { $0.position(from: targetFrame) },
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
