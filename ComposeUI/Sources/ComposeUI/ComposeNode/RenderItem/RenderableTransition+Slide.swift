//
//  RenderableTransition+Slide.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/23/24.
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
    /// For insertion, the renderable starts outside the content view on the `from` side (with `overshoot` applied) and slides into `targetFrame`.
    /// For removal, the renderable slides from its current frame to outside the content view on the `to` side (or `from` when `to` is nil).
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
                switch toSide ?? fromSide {
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
