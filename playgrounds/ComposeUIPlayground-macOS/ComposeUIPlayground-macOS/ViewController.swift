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
    VStack {
      HStack { rainbowColorNodes }.frame(width: .flexible, height: 20)

      Spacer(height: 16)

      Text("Hello, ComposéUI!")
        .frame(width: .intrinsic, height: .intrinsic)
        .transition(.opacity(timing: .linear(duration: 2)))

      Spacer(height: 8)

      Text("Building UI using UIKit/AppKit with declarative syntax")
        .textColor(.secondaryLabelColor)
        .transition(.opacity(timing: .linear(duration: 2, delay: 0.5)))

      Spacer(height: 16)

      HStack(spacing: 4) { rainbowColorNodes }
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

      ViewNode<Playground.SwiftUIView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 120)

      Spacer(height: 16)

      ButtonNode { state in
        switch state {
        case .normal,
             .hovered:
          ColorNode(Colors.blueGray)
        case .pressed,
             .selected:
          ColorNode(Colors.darkBlueGray)
        case .disabled:
          ColorNode(Colors.lightBlueGray)
        }
      } onTap: {
        print("tap")
      }
      .onDoubleTap {
        print("double tap")
      }
      .frame(width: 88, height: 44)

      Spacer(height: 16)

      ViewNode<Playground.LabelView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 720)

      Spacer().height(20)

      VStack {
        rainbowColorNodes.map { $0.frame(width: .flexible, height: 100) }
      }

      ColorNode(.red)
        .padding(horizontal: 100, vertical: 20)
        .frame(width: .flexible, height: 100)
        .rotate(by: 30)

      HStack { rainbowColorNodes }.frame(width: .flexible, height: 20)
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

private let rainbowColorNodes = [
  ColorNode(Colors.RetroApple.green),
  ColorNode(Colors.RetroApple.yellow),
  ColorNode(Colors.RetroApple.orange),
  ColorNode(Colors.RetroApple.red),
  ColorNode(Colors.RetroApple.purple),
]
