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

  class ViewState {

    weak var view: ComposeView!
    var color: UIColor = .red
    var colorSize: CGFloat = 500
    var cornerRadius: CGFloat = 16

    lazy var subtitleLabel: UILabel = {
      let label = UILabel()
      label.text = "Building UI using UIKit/AppKit with declarative syntax"
      label.textAlignment = .center
      label.font = .systemFont(ofSize: 14)
      label.textColor = .secondaryLabel
      label.sizeToFit()
      return label
    }()
  }

  private let state = ViewState()

  private lazy var contentView = ComposeView { [state] in
    Spacer().height(60)

    ViewNode<UILabel>(
      update: { label, _ in
        label.text = "Hello, ComposéUI!"
        label.textAlignment = .center
      }
    )
    .frame(width: 200, height: 50)

    state.subtitleLabel

    VStack(spacing: 8) {

      ViewNode<Playground.FrameView>()
        .frame(width: .flexible, height: state.view.bounds.width - Constants.padding * 2)

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
    .border(color: .black.withAlphaComponent(0.5), width: 1)
    .cornerRadius(state.cornerRadius)
    .padding(Constants.padding)
    .frame(width: .flexible, height: .intrinsic)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    state.view = contentView

    view.addSubview(contentView)
    contentView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: view.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    let button = UIButton(type: .system)
    button.setTitle("Change Color", for: .normal)
    button.addTarget(self, action: #selector(changeColor), for: .touchUpInside)
    view.addSubview(button)
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
    ])
  }

  @objc private func changeColor() {
    state.color = UIColor(red: .random(in: 0 ... 1), green: .random(in: 0 ... 1), blue: .random(in: 0 ... 1), alpha: 1)
    state.colorSize = CGFloat.random(in: 100 ... 400)
    state.cornerRadius = CGFloat.random(in: 0 ... 16)
    contentView.refresh()
  }

  // MARK: - Constants

  private enum Constants {
    static let padding: CGFloat = 16
  }
}
