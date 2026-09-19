//
//  FrameTrackingRenderables.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/18/26.
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

import QuartzCore

import ComposeUI

/// A view that counts how many times its `frame` is set, to verify that unchanged frames are not re-applied.
final class FrameTrackingView: BaseView {

  private(set) var frameSetCount = 0

  /// Resets the counter, for example to ignore the frame set by the initial insert.
  func resetFrameSetCount() {
    frameSetCount = 0
  }

  override var frame: CGRect {
    get {
      super.frame
    }
    set {
      frameSetCount += 1
      super.frame = newValue
    }
  }
}

/// A layer that counts how many times its `frame` is set, to verify that unchanged frames are not re-applied.
final class FrameTrackingLayer: CALayer {

  private(set) var frameSetCount = 0

  /// Resets the counter, for example to ignore the frame set by the initial insert.
  func resetFrameSetCount() {
    frameSetCount = 0
  }

  override var frame: CGRect {
    get {
      super.frame
    }
    set {
      frameSetCount += 1
      super.frame = newValue
    }
  }
}
