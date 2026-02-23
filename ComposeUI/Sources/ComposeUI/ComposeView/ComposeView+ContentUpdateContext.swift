//
//  ComposeView+ContentUpdateContext.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import Foundation

extension ComposeView {

    struct ContentUpdateContext: Equatable {

        enum ContentUpdateType: Equatable {

            /// Explicit refresh request, with a flag to indicate if the refresh is animated.
            case refresh(isAnimated: Bool)

            /// The view bounds changed, the previous render bounds is provided.
            case boundsChange(previousRenderBounds: CGRect)
        }

        /// The render update type.
        let updateType: ContentUpdateType

        /// The bounds used for rendering.
        let renderBounds: CGRect

        var isRendering: Bool = false

        init(updateType: ContentUpdateType, renderBounds: CGRect) {
            self.updateType = updateType
            self.renderBounds = renderBounds
        }

        func shouldAnimate(contentView: ComposeView, animationBehavior: AnimationBehavior) -> Bool {
            switch animationBehavior {
            case .default:
                switch updateType {
                case .refresh(let isAnimated):
                    return isAnimated
                case .boundsChange(let previousRenderBounds):
                    if previousRenderBounds.size == renderBounds.size {
                        // scroll
                        return true
                    } else {
                        // size change
                        return false
                    }
                }
            case .disabled:
                return false
            case .dynamic(let shouldAnimate):
                let renderType: ComposeView.RenderType
                switch updateType {
                case .refresh(let isAnimated):
                    renderType = .refresh(isAnimated: isAnimated)
                case .boundsChange(let previousRenderBounds):
                    if previousRenderBounds.size == renderBounds.size {
                        renderType = .scroll(previousBounds: previousRenderBounds)
                    } else {
                        renderType = .boundsChange(previousBounds: previousRenderBounds)
                    }
                }
                return shouldAnimate(contentView, renderType)
            }
        }
    }
}
