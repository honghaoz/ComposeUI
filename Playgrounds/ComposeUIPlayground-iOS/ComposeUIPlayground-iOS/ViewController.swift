//
//  ViewController.swift
//  ComposeUIPlayground-iOS
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit
import ComposeUI

class ViewController: UIViewController {

  class ViewModel {
    var color: UIColor = .red
    var colorSize: CGFloat = 500
    var cornerRadius: CGFloat = 16
  }

  private var viewModel = ViewModel()

  private lazy var contentView = ComposeContentView { [weak self] _ in
    self?.content ?? Spacer()
  }

  @ComposeContentBuilder
  private var content: ComposeContent {
    VStack(spacing: 8) {
      Spacer().height(44)

      for _ in 0 ... 50 {
        Color(viewModel.color)
          .frame(width: .flexible, height: viewModel.colorSize)
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
          .frame(width: .flexible, height: .fixed(viewModel.colorSize))
      }

      Spacer().height(44)
    }
    .border(color: .black, width: 1)
    .cornerRadius(viewModel.cornerRadius)
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
    viewModel.color = UIColor.init(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
    viewModel.colorSize = CGFloat.random(in: 100...400)
    viewModel.cornerRadius = CGFloat.random(in: 0...16)
    contentView.refresh()
  }
}
