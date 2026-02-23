//
//  UIScrollView+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/27/24.
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
}
