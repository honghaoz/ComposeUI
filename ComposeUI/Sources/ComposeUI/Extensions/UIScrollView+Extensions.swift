//
//  UIScrollView+Extensions.swift
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

import UIKit

public extension UIScrollView {

  /// The minimum horizontal offset that the scroll view can scroll to, without elastic effect.
  var minOffsetX: CGFloat {
    -adjustedContentInset.left
  }

  /// The maximum horizontal offset that the scroll view can scroll to, without elastic effect.
  var maxOffsetX: CGFloat {
    contentSize.width - bounds.width + adjustedContentInset.right
  }

  /// The minimum vertical offset that the scroll view can scroll to, without elastic effect.
  var minOffsetY: CGFloat {
    -adjustedContentInset.top
  }

  /// The maximum vertical offset that the scroll view can scroll to, without elastic effect.
  var maxOffsetY: CGFloat {
    contentSize.height - bounds.height + adjustedContentInset.bottom
  }

  /// Whether the scroll view can scroll to the left.
  var canScrollToLeft: Bool {
    contentOffset.x > minOffsetX
  }

  /// Whether the scroll view can scroll to the right.
  var canScrollToRight: Bool {
    contentOffset.x < maxOffsetX
  }

  /// Whether the scroll view can scroll to the top.
  var canScrollToTop: Bool {
    contentOffset.y > minOffsetY
  }

  /// Whether the scroll view can scroll to the bottom.
  var canScrollToBottom: Bool {
    contentOffset.y < maxOffsetY
  }

  /// Stops any ongoing scroll deceleration, freezing the scroll view at its current position.
  func stopDecelerating() {
    setContentOffset(contentOffset, animated: false)
  }
}
