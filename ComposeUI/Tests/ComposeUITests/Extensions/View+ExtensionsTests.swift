//
//  View+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/27/26.
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

@testable import ComposeUI

class View_ExtensionsTests: XCTestCase {

  func test_intrinsicSize_usesSizeThatFits() {
    #if canImport(AppKit)
    let view = IntrinsicSizeView(fittingSize: CGSize(width: 11, height: 22))
    #endif

    #if canImport(UIKit)
    let view = IntrinsicSizeView(
      sizeThatFitsValue: CGSize(width: 11, height: 22),
      systemLayoutSizeValue: CGSize(width: 33, height: 44)
    )
    #endif

    view.translatesAutoresizingMaskIntoConstraints = true

    let size = view.intrinsicSize(for: CGSize(width: 100, height: 200))
    expect(size) == CGSize(width: 11, height: 22)
  }

  func test_intrinsicSize_usesSystemLayoutSizeFitting() {
    #if canImport(AppKit)
    let view = IntrinsicSizeView(fittingSize: CGSize(width: 33, height: 44))
    #endif

    #if canImport(UIKit)
    let view = IntrinsicSizeView(
      sizeThatFitsValue: CGSize(width: 11, height: 22),
      systemLayoutSizeValue: CGSize(width: 33, height: 44)
    )
    #endif

    view.translatesAutoresizingMaskIntoConstraints = false

    let size = view.intrinsicSize(for: CGSize(width: 100, height: 200))
    expect(size) == CGSize(width: 33, height: 44)
  }
}

#if canImport(AppKit)
private final class IntrinsicSizeView: NSView {

  private let _fittingSize: CGSize

  init(fittingSize: CGSize) {
    self._fittingSize = fittingSize

    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented") // swiftlint:disable:this fatal_error
  }

  override var fittingSize: CGSize {
    _fittingSize
  }
}
#endif

#if canImport(UIKit)
private final class IntrinsicSizeView: View {

  private let sizeThatFitsValue: CGSize
  private let systemLayoutSizeValue: CGSize

  init(sizeThatFitsValue: CGSize, systemLayoutSizeValue: CGSize) {
    self.sizeThatFitsValue = sizeThatFitsValue
    self.systemLayoutSizeValue = systemLayoutSizeValue
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented") // swiftlint:disable:this fatal_error
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    sizeThatFitsValue
  }

  override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
    systemLayoutSizeValue
  }
}
#endif
