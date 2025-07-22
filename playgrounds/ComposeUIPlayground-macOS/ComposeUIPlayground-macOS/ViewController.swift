//
//  ViewController.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/27/24.
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

import AppKit

import ComposeUI

class ViewController: NSViewController {

  private lazy var contentView = ComposeView { contentView in
    let isKey = (contentView.window?.isKeyWindow ?? true)

    VStack {
      HStack {
        rainbowColorNodes(isKeyWindow: isKey)
      }
      .frame(width: .flexible, height: 20)

      Spacer(height: 16)

      Label("Hello, ComposéUI!")
        .font(.systemFont(ofSize: 24))
        .shadow(color: .black, opacity: 0.5, radius: 1, offset: CGSize(width: 2, height: 2), path: nil)
        .transition(.opacity(timing: .linear(duration: 2)))

      Spacer(height: 8)

      Label("Building UI using UIKit/AppKit with declarative syntax")
        .textColor(.secondaryLabelColor)
        .transition(.opacity(timing: .linear(duration: 2, delay: 0.5)))

      Spacer(height: 16)

      HStack(spacing: 4) {
        rainbowColorNodes(isKeyWindow: isKey)
      }
      .rotate(by: 30)
      .frame(width: .flexible, height: 20)
      .cornerRadius(4)

      Spacer(height: 16)

      ViewNode<Playground.TransitionView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 120)

      Spacer(height: 16)

      ViewNode<Playground.FrameView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: contentView.bounds.width)

      Spacer(height: 16)

      ViewNode<Playground.LayersView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: contentView.bounds.width)

      Spacer(height: 16)

      ViewNode<Playground.ShadowView>()
        .underlay {
          ColorNode(.white)
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 1000)

      Spacer(height: 16)

      ViewNode<Playground.SwiftUIView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 120)

      Spacer(height: 16)

      ViewNode<Playground.Button>()
        .frame(width: .flexible, height: 44)
        .padding(horizontal: 0, vertical: 16)
        .frame(width: .flexible, height: .intrinsic)
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)

      Spacer(height: 16)

      ViewNode<Playground.LabelView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 1024)

      Spacer(height: 16)

      ViewNode<Playground.TextView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 640)

      Spacer().height(20)

      ViewNode<Playground.ScrollView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 100)

      Spacer().height(20)

      ViewNode(
        make: { _ in
          let view = ComposeView(content: {
            LabelNode("Text with Scroll Bars")
              .font(Font.systemFont(ofSize: 14, weight: .regular))
              .background {
                ColorNode(.red)
              }
          })
          view.frame.size = view.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
          )
          return view
        },
      )
      .fixedSize()

      Spacer().height(20)

      VStack {
        rainbowColorNodes(isKeyWindow: isKey).map { $0.frame(width: .flexible, height: 100) }
      }

      ColorNode(.red)
        .padding(horizontal: 100, vertical: 20)
        .frame(width: .flexible, height: 100)
        .rotate(by: 30)

      HStack { rainbowColorNodes(isKeyWindow: isKey) }.frame(width: .flexible, height: 20)
    }
    .frame(width: .flexible, height: .intrinsic)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.wantsLayer = true

    self.view.addSubview(contentView)
    contentView.frame = view.bounds
    contentView.autoresizingMask = [.width, .height]
  }

  override func viewDidAppear() {
    super.viewDidAppear()

    if let window = view.window {
      window.minSize.width = 300
      window.title = "ComposéUI"
    }
  }
}

private func rainbowColorNodes(isKeyWindow: Bool = true) -> [ColorNode] {
  [
    ColorNode(Colors.RetroApple.green.withAlphaComponent(isKeyWindow ? 1 : 0.5)),
    ColorNode(Colors.RetroApple.yellow.withAlphaComponent(isKeyWindow ? 1 : 0.5)),
    ColorNode(Colors.RetroApple.orange.withAlphaComponent(isKeyWindow ? 1 : 0.5)),
    ColorNode(Colors.RetroApple.red.withAlphaComponent(isKeyWindow ? 1 : 0.5)),
    ColorNode(Colors.RetroApple.purple.withAlphaComponent(isKeyWindow ? 1 : 0.5)),
  ]
}
