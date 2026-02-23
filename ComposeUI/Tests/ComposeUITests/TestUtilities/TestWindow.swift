//
//  TestWindow.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/22/26.
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
import QuartzCore

/// A test window that can be used to test window-related functionality.
public final class TestWindow: UIWindow {

  // MARK: - Content View

  public func contentView() -> UIView {
    return _contentView! // swiftlint:disable:this force_unwrapping
  }

  private var _contentView: UIView!

  // MARK: - Init

  public init() {
    super.init(frame: CGRect(x: 0, y: 0, width: Constants.windowWidth, height: Constants.windowHeight))

    self.makeKeyAndVisible()

    _contentView = UIView(frame: self.bounds)
    addSubview(_contentView)
    _contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  // MARK: - Constants

  private enum Constants {
    static let windowWidth: CGFloat = 500
    static let windowHeight: CGFloat = 500
  }
}
