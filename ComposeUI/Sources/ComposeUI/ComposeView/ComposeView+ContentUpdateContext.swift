//
//  ComposeView+ContentUpdateContext.swift
//  ComposeUI
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

import Foundation

extension ComposeView {

  struct ContentUpdateContext {

    enum ContentUpdateType {

      /// Explicit refresh request, with a flag to indicate if the refresh is animated.
      case refresh(isAnimated: Bool)

      /// View bounds changed.
      case boundsChange(previousBounds: CGRect)
    }

    let updateType: ContentUpdateType

    var isRendering: Bool = false

    var isAnimated: Bool {
      switch updateType {
      case .refresh(let isAnimated):
        return isAnimated
      case .boundsChange:
        return false // TODO: should support configurable animation for bounds change
      }
    }

    init(updateType: ContentUpdateType) {
      self.updateType = updateType
    }
  }
}
