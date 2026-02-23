//
//  RenderableTransition+Opacity.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/18/24.
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
