//
//  BaseLabel.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
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

/// A base class of `NSLabel`.
open class BaseLabel: NSLabel {

  override open var isFlipped: Bool { true }

  override open var wantsUpdateLayer: Bool {
    true // this value affects the label's intrinsic size (sizeThatFits)
  }

  public var isUserInteractionEnabled: Bool = false {
    didSet {
      refusesFirstResponder = !isUserInteractionEnabled
      ignoreHitTest = !isUserInteractionEnabled
    }
  }

  override open var acceptsFirstResponder: Bool {
    if isUserInteractionEnabled == true {
      return true
    } else {
      return super.acceptsFirstResponder
    }
  }

  override open func becomeFirstResponder() -> Bool {
    if isUserInteractionEnabled == false {
      return false
    } else {
      return super.becomeFirstResponder()
    }
  }
}
#endif

#if canImport(UIKit)
import UIKit

/// A base class of `UILabel`.
open class BaseLabel: UILabel {

  /// The vertical alignment of the text. Default to `.center`.
  public var verticalAlignment: TextVerticalAlignment = .center

  override open func draw(_ rect: CGRect) {
    switch verticalAlignment {
    case .top:
      // https://stackoverflow.com/a/41367948/3164091
      let textRect = super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
      super.drawText(in: textRect)
    case .center:
      // by default, the text is centered
      super.drawText(in: rect)
    case .bottom:
      ComposeUI.assertFailure("unsupported bottom alignment")
      super.drawText(in: rect)
    }
  }
}
#endif
