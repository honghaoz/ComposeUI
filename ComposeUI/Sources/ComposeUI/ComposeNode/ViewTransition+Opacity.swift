//
//  ViewTransition+Opacity.swift
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

public extension ViewTransition {

  static func opacity(from: CGFloat = 0,
                      to: CGFloat = 1,
                      timing: AnimationTiming = .easeInEaseOut(duration: Animations.defaultAnimationDuration),
                      options: TransitionOptions = .both) -> ViewTransition
  {
    ViewTransition(
      insert: options.contains(.insert) ? InsertTransition(from: from, to: to, timing: timing) : nil,
      remove: options.contains(.remove) ? RemoveTransition(to: from, timing: timing) : nil
    )
  }
}

private struct InsertTransition: ViewInsertTransition {

  private let from: CGFloat
  private let to: CGFloat
  private let timing: AnimationTiming

  init(from: CGFloat, to: CGFloat, timing: AnimationTiming) {
    self.from = from
    self.to = to
    self.timing = timing
  }

  func animate(view: Renderable, context: ViewInsertTransitionContext, completion: @escaping () -> Void) {
    view.setFrame(context.targetFrame)

    let layer = view.layer

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
  }
}

private struct RemoveTransition: ViewRemoveTransition {

  private let to: CGFloat
  private let timing: AnimationTiming

  init(to: CGFloat, timing: AnimationTiming) {
    self.to = to
    self.timing = timing
  }

  func animate(view: Renderable, context: ViewRemoveTransitionContext, completion: @escaping () -> Void) {
    view.layer.animate(
      keyPath: "opacity",
      timing: timing,
      from: { $0.opacity - Float(to) },
      to: { _ in 0 },
      model: { _ in Float(to) },
      updateAnimation: {
        $0.isAdditive = true
        $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
          completion()
        })
      }
    )
  }
}
