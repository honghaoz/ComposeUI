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

  private class ViewState {

    private(set) lazy var textField = NSTextField()
  }

  private let state = ViewState()

  private lazy var contentView = ComposeView { [state] contentView in
    VStack {
      HStack { rainbowColorNodes }.frame(width: .flexible, height: 20)

      Spacer(height: 16)

      state.textField
        .asComposeNode()
        .flexible()
        .frame(width: 200, height: 22)
        .transition(.opacity(timing: .linear(duration: 2)))

      Spacer(height: 16)

      HStack(spacing: 4) { rainbowColorNodes }
        .rotate(by: 30)
        .frame(width: .flexible, height: 20)
        .cornerRadius(4)

      Spacer(height: 16)

      ViewNode<Playground.SwiftUIView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 120)

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

      Spacer().height(20)

      VStack {
        ColorNode(.red).frame(width: .flexible, height: 100)
        ColorNode(.orange).frame(width: .flexible, height: 100)
        ColorNode(.yellow).frame(width: .flexible, height: 100)
        ColorNode(.green).frame(width: .flexible, height: 100)
        ColorNode(.blue).frame(width: .flexible, height: 100)
        ColorNode(.purple).frame(width: .flexible, height: 100)
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

    let textField = state.textField
    textField.wantsLayer = true
    textField.stringValue = "Hello, ComposéUI!"
    textField.isEditable = false
    textField.isBordered = false
    textField.drawsBackground = false
    textField.font = .systemFont(ofSize: 18, weight: .medium)
    textField.alignment = .center

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
  ColorNode(.red),
  ColorNode(.orange),
  ColorNode(.yellow),
  ColorNode(.green),
  ColorNode(.blue),
  ColorNode(.purple),
]
