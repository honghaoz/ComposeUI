//
//  Playground+TransitionView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/23/24.
//

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ComposeUI

extension Playground {

    final class TransitionView: AnimatingComposeView {

        private var isShowing = true
        private var side: RenderableTransition.SlideSide = .left

        @ComposeContentBuilder
        override var content: ComposeContent {
            if isShowing {
                ColorNode(Colors.blueGray)
                    .transition(.slide(from: side))
                    .frame(width: 100, height: 40)
                    .frame(.flexible, alignment: .center)
            } else {
                Empty()
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            // animationBehavior = .disabled
            clippingBehavior = .always
        }

        override func animate() {
            isShowing.toggle()
            if !isShowing {
                switch side {
                case .left:
                    side = .bottom
                case .bottom:
                    side = .right
                case .right:
                    side = .top
                case .top:
                    side = .left
                }
            }

            refresh()
        }
    }
}
