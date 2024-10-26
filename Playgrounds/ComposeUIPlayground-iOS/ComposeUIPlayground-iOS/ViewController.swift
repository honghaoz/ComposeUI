//
//  ViewController.swift
//  ComposeUIPlayground-iOS
//
//  Created by Honghao Zhang on 9/29/24.
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

  private lazy var contentView = ComposeContentView { [state] in
    Spacer().height(60)

    LabelNode("Hey")

    View<UILabel>(
      update: { label in
        label.text = "Hello, ComposeUI!"
        label.textAlignment = .center
      }
    )
    .frame(width: 200, height: 50)

    state.subtitleLabel

    VStack(spacing: 8) {
      for _ in 0 ... 50 {
        Color(state.color)
          .frame(width: .flexible, height: state.colorSize)
          .overlay {
            Color(.red).frame(50)
          }
          .underlay {
            Color(.black).frame(100)
          }

        HStack(spacing: 8) {
          Color(.green)
          Color(.yellow)
          Color(.blue)
        }
        .frame(width: .flexible, height: 50)

        HStack {
          Color(.green)
          Color(.yellow)
            .padding(20)
            .frame(.flexible)
          Color(.red)
          Spacer()
            .background(Color(.black))
        }
        .frame(width: .flexible, height: 100)

        ZStack {
          Color(.red.withAlphaComponent(0.75))
          Color(.yellow.withAlphaComponent(0.5)).padding(horizontal: 16, vertical: 4)
        }
        .frame(width: .flexible, height: 50)

        Color(.blue)
          .frame(width: .flexible, height: .fixed(state.colorSize))
      }

      Spacer().height(44)
    }
    .border(color: .black, width: 1)
    .cornerRadius(state.cornerRadius)
    .padding(16)
    .frame(width: .flexible, height: .intrinsic)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

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
      button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
    ])
  }

  @objc private func changeColor() {
    state.color = UIColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
    state.colorSize = CGFloat.random(in: 100...400)
    state.cornerRadius = CGFloat.random(in: 0...16)
    contentView.refresh()
  }
}
