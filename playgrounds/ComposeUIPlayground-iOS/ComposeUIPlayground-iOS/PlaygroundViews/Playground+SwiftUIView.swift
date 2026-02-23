//
//  Playground+SwiftUIView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/19/25.
//

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ComposeUI
import SwiftUI

extension Playground {

    final class SwiftUIView: AnimatingComposeView {

        private var isShowing = true

        @ComposeContentBuilder
        override var content: ComposeContent {
            VStack {
                HStack {
                    Label("Static SwiftUI View: ").font(.systemFont(ofSize: 11)).textAlignment(.left)
                        .fixedSize(width: false, height: true)
                        .frame(width: 120, height: .intrinsic)
                    Spacer(width: 4)
                    SwiftUIViewNode(id: "static", SwiftUIPlaygroundView())
                        .border(color: Color.green.withAlphaComponent(0.25), width: 1)
                }

                Spacer(height: 16)

                HStack {
                    Label("Dynamic SwiftUI View: ").font(.systemFont(ofSize: 11)).textAlignment(.left)
                        .fixedSize(width: false, height: true)
                        .frame(width: 120, height: .intrinsic)
                    Spacer(width: 4)
                    SwiftUIViewNode { [weak self] in
                        guard let self else {
                            return AnyView(Text("..."))
                        }
                        return isShowing ? AnyView(SwiftUIPlaygroundView()) : AnyView(Text("..."))
                    }
                    .border(color: Color.green.withAlphaComponent(0.25), width: 1)
                }
            }
            .padding(8)
        }

        override func animate() {
            isShowing.toggle()
            refresh()
        }
    }
}

private struct SwiftUIPlaygroundView: SwiftUI.View {

    @State private var isShowing = false

    var body: some SwiftUI.View {
        SwiftUI.ZStack {
            if isShowing {
                SwiftUI.HStack(spacing: 8) {
                    SwiftUI.Text("This is SwiftUI")
                    if #available(iOS 14.0, macOS 11.0, *) {
                        SwiftUI.Image(systemName: "swift")
                            .foregroundColor(Color(red: 1.0, green: 0.427, blue: 0.0))
                    }
                }
                .font(.system(size: 18))
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.2).combined(with: .slide).combined(with: .opacity),
                        removal: .scale(scale: 0.5).combined(with: .opacity).combined(with: .slide)
                    )
                )
            }

            // an overlay rectangle to make the view tappable
            SwiftUI.Rectangle()
                .opacity(0.001) // nearly invisible but still tappable
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation {
                            self.isShowing = true
                        }
                    }
                }
                .onTapGesture {
                    withAnimation {
                        self.isShowing.toggle()
                    }
                }
        }
    }
}
