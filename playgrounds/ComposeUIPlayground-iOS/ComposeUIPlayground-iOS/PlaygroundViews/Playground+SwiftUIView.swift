//
//  Playground+SwiftUIView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/19/25.
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
      SwiftUIViewNode { [weak self] in
        guard let self else {
          return AnyView(Text("..."))
        }
        return isShowing ? AnyView(SwiftUIPlaygroundView()) : AnyView(Text("..."))
      }
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
