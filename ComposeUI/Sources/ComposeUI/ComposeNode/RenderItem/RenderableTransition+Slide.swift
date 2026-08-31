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
  /// For insertion, the renderable starts outside the content view on the `from` side (with `overshoot` applied) and
  /// slides into `targetFrame`.
  /// For removal, the renderable slides from its current frame to outside the content view on the `to` side (or `from`
  /// when `to` is nil).
  ///
  /// Reviving a renderable while its slide-out is in flight continues the motion: the insertion's offset from the
  /// removal's model position cancels the model change, so the rendered position doesn't jump, and the leftover exit
  /// offset keeps decaying on top while both animations settle into the resting position. This holds for any side
  /// configuration, so a revival re-enters from wherever the removal left it: a renderable that fully slid out
  /// re-enters from its exit side, and the `from` side only applies to fresh insertions.
  ///
  /// The composed revival motion's quality depends on the timings: curves that start at rest (springs, ease-in-out)
  /// keep the velocity continuous, an equal-duration linear pair cancels to a standstill until the leftover decays,
  /// and strongly mismatched durations can overshoot the resting position before settling.
  ///
  /// A zero-duration timing applies the end frame and completes immediately when there is no delay, and a zero-duration
  /// revival also clears the leftover exit animations so the snap lands at rest. With a delay, the end frame is
  /// scheduled as a snap that applies right after the delay window.
  ///
  /// - Parameters:
  ///   - from: The side of the slide transition to slide from.
  ///   - to: The side of the slide transition to slide to for removal. Defaults to `from` when nil.
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
      insert: options.contains(.insert) ? InsertTransition(takesOverKeyPaths: ["position"]) { renderable, context, completion in
        let layer = renderable.layer
        let targetFrame = context.targetFrame

        guard timing.timing.duration > 0 || timing.delay > 0 else {
          if context.revivalPosition != nil {
            // the taken-over leftover exit animations would render the snapped model off the target until they decay,
            // so a snap clears them
            layer.removeAnimations(forKeyPath: "position")
          }
          renderable.setFrame(targetFrame)
          completion()
          return
        }

        let startPosition: CGPoint
        if let revivalPosition = context.revivalPosition {
          // a revival continues from the removal's model position: the offset from that position cancels the model
          // change exactly, so the rendered position doesn't move at the revival instant, and the removal's leftover
          // offset keeps decaying on top
          startPosition = revivalPosition
        } else {
          let startFrame: CGRect
          switch fromSide {
          case .top:
            startFrame = targetFrame.translate(dy: -targetFrame.maxY - overshoot)
          case .bottom:
            startFrame = targetFrame.translate(dy: context.contentView.bounds().height - targetFrame.minY + overshoot)
          case .left:
            startFrame = targetFrame.translate(dx: -targetFrame.maxX - overshoot)
          case .right:
            startFrame = targetFrame.translate(dx: context.contentView.bounds().width - targetFrame.minX + overshoot)
          }
          startPosition = layer.position(from: startFrame)
        }

        renderable.setFrame(targetFrame)

        layer.animate(
          keyPath: "position",
          timing: timing,
          from: { startPosition - $0.position(from: targetFrame) },
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
      remove: options.contains(.remove) ? RemoveTransition(
        animatedKeyPaths: ["position"],
        animate: { renderable, context, completion in
          let layer = renderable.layer
          let currentFrame = layer.frame

          let targetFrame: CGRect
          switch toSide ?? fromSide {
          case .top:
            targetFrame = currentFrame.translate(dy: -currentFrame.maxY - overshoot)
          case .bottom:
            targetFrame = currentFrame.translate(dy: context.contentView.bounds().height - currentFrame.minY + overshoot)
          case .left:
            targetFrame = currentFrame.translate(dx: -currentFrame.maxX - overshoot)
          case .right:
            targetFrame = currentFrame.translate(dx: context.contentView.bounds().width - currentFrame.minX + overshoot)
          }

          guard timing.timing.duration > 0 || timing.delay > 0 else {
            renderable.setFrame(targetFrame)
            completion()
            return
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
        }
      ) : nil
    )
  }
}
