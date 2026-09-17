//
//  RenderPassLabViewController.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/17/26.
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

/// A full-screen page for the render pass lab, with a close button above it.
final class RenderPassLabViewController: UIViewController {

  private let lab = Playground.RenderPassLab(frame: .zero)

  private lazy var closeButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Close", for: .normal)
    button.addTarget(self, action: #selector(close), for: .touchUpInside)
    return button
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .systemBackground
    view.addSubview(closeButton)
    view.addSubview(lab)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    let safeArea = view.safeAreaInsets
    closeButton.frame = CGRect(x: view.bounds.width - safeArea.right - Constants.closeButtonWidth, y: safeArea.top, width: Constants.closeButtonWidth, height: Constants.closeButtonHeight)

    let labTop = safeArea.top + Constants.closeButtonHeight
    lab.frame = CGRect(x: safeArea.left, y: labTop, width: view.bounds.width - safeArea.left - safeArea.right, height: view.bounds.height - labTop - safeArea.bottom)
  }

  @objc private func close() {
    dismiss(animated: true)
  }

  // MARK: - Constants

  private enum Constants {
    static let closeButtonWidth: CGFloat = 80
    static let closeButtonHeight: CGFloat = 36
  }
}
