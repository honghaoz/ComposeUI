//
//  ViewController.swift
//  ComposeUIPlayground-iOS
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit
import ComposeUI

class ViewController: UIViewController {

  private lazy var contentView = ComposeContentView { [weak self] _ in
    guard let self else {
      return Empty()
    }
    return self.content
  }

  class ViewModel {

    var color: UIColor = .red
    var colorSize: CGFloat = 500
  }

  private var viewModel = ViewModel()

  @ComposeContentBuilder
  private var content: ComposeContent {
    VerticalStack {
      for _ in 0 ... 50 {
        Color(viewModel.color)
          .frame(width: .flexible, height: viewModel.colorSize)
          .overlay {
            Color(.red).frame(50)
          }
          .underlay {
            Color(.black).frame(100)
          }
        
        Spacer()

        HStack {
          Color(.green)
          Color(.yellow).padding(vertical: 20)
          Color(.yellow)
        }
        HStack {
          Color(.green)
          Color(.yellow)
            .padding(horizontal: 20, vertical: 50)
            .frame(.flexible)
          Color(.red)
          Spacer()
        }
        LayeredStack {
          Color(.yellow.withAlphaComponent(0.5)).padding(20)
          Color(.red.withAlphaComponent(0.5))
        }
        Color(.blue)
          .frame(width: .flexible, height: .fixed(viewModel.colorSize))
      }
    }
    .border(color: .blue, width: 2)
    .cornerRadius(8)
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

    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
      self.scrollToBottom()
    })
  }

  private func scrollToBottom() {
    contentView.setContentOffset(CGPoint(x: 0, y: 2000), animated: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
      self.scrollToTop()
    })
  }

  private func scrollToTop() {
    contentView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
      self.scrollToBottom()
    })
  }

  @objc private func changeColor() {
    viewModel.color = UIColor.init(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
    viewModel.colorSize = CGFloat.random(in: 100...1500)
    contentView.refresh()
  }
}
