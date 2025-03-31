//
//  ViewController.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

import UIKit
import ComposeUI

class ViewController: UIViewController {

  /// Memory Diagram:
  ///
  /// ViewController ----> ContentView
  ///       |                  |
  ///       |                  |
  ///       |                  v
  ///       +------------> ViewModel
  ///

  private class ViewState {

    var color: UIColor = .red
    var colorSize: CGFloat = 200

    lazy var subtitleLabel: UILabel = {
      let label = UILabel()
      label.text = "Building UI using UIKit/AppKit with declarative syntax"
      label.textAlignment = .center
      label.font = .systemFont(ofSize: 14)
      label.textColor = .secondaryLabel
      label.sizeToFit()
      return label
    }()

    lazy var playgroundTextView = Playground.TextView()
  }

  private let state = ViewState()

  private lazy var contentView = ComposeView { [state] contentView in
    Spacer().height(60)

    Text("Hello, ComposéUI!")
      .transition(.slide(from: .top))
      .frame(width: 200, height: 50)
      .transition(.opacity(timing: .linear(duration: 2)))

    ViewNode(state.subtitleLabel)
      .transition(.opacity(timing: .linear(duration: 2, delay: 1)))

    VStack(spacing: 8) {

      ViewNode<Playground.SwiftUIView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: Constants.padding)
        .frame(width: .flexible, height: 120)

      ViewNode<Playground.TransitionView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: Constants.padding)
        .frame(width: .flexible, height: 120)

      ViewNode<Playground.FrameView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: Constants.padding)
        .frame(width: .flexible, height: contentView.bounds.width)

      ViewNode<Playground.ShadowView>()
        .underlay {
          ColorNode(.white)
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: Constants.padding)
        .frame(width: .flexible, height: contentView.bounds.width)

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
      } onTap: { [weak self] in
        self?.changeColor()
      }
      .onDoubleTap {
        print("double tap")
      }
      .padding(horizontal: 44)
      .frame(width: .flexible, height: 44)

      ViewNode<ButtonView>(
        update: { view, context in
          guard context.updateType == .insert else {
            return
          }

          view.configure { state, _ in
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
          } onTap: { [weak self] in
            self?.changeColor()
          } onDoubleTap: {
            print("double tap 2")
          }
        }
      )
      .frame(width: 100, height: 44)

      ViewNode<Playground.LabelView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 900)

      ViewNode(state.playgroundTextView) // use a cached text view to avoid bad performance
        .flexibleSize()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 900)

      ViewNode<Playground.ScrollView>()
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .padding(horizontal: 16)
        .frame(width: .flexible, height: 100)

      for _ in 0 ... 50 {
        ColorNode(state.color)
          .frame(width: .flexible, height: state.colorSize)
          .overlay {
            ColorNode(.red).frame(50)
          }
          .underlay {
            ColorNode(.black).frame(100)
          }

        HStack(spacing: 8) {
          ColorNode(.green)
          ColorNode(.yellow)
          ColorNode(.blue)
        }
        .frame(width: .flexible, height: 50)

        HStack {
          ColorNode(.green)
          ColorNode(.yellow)
            .padding(20)
            .frame(.flexible)
          ColorNode(.red)
          Spacer()
            .background(ColorNode(.black))
        }
        .frame(width: .flexible, height: 100)

        ZStack {
          ColorNode(.red.withAlphaComponent(0.75))
          ColorNode(.yellow.withAlphaComponent(0.5)).padding(horizontal: 16, vertical: 4)
        }
        .frame(width: .flexible, height: 50)

        ColorNode(.blue)
          .frame(width: .flexible, height: .fixed(state.colorSize))
      }

      Spacer().height(44)
    }
    .border(color: .gray, width: 1)
    .padding(Constants.padding)
    .frame(width: .flexible, height: .intrinsic)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(contentView)
    contentView.frame = view.bounds
    contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
  }

  private func changeColor() {
    state.color = UIColor(red: .random(in: 0 ... 1), green: .random(in: 0 ... 1), blue: .random(in: 0 ... 1), alpha: 1)
    state.colorSize = CGFloat.random(in: 120 ... 240)
    contentView.refresh()
  }

  // MARK: - Constants

  private enum Constants {
    static let padding: CGFloat = 16
  }
}
