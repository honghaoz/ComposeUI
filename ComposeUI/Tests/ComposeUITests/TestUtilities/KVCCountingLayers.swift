//
//  KVCCountingLayers.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/27/26.
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

/// A layer that counts its KVC reads and writes, to verify which reads and writes skip KVC.
final class KVCCountingLayer: CALayer {

  private(set) var kvcReadCount = 0

  private(set) var kvcWriteCount = 0

  override func value(forKeyPath keyPath: String) -> Any? {
    kvcReadCount += 1
    return super.value(forKeyPath: keyPath)
  }

  override func setValue(_ value: Any?, forKeyPath keyPath: String) {
    kvcWriteCount += 1
    super.setValue(value, forKeyPath: keyPath)
  }
}

/// A shape layer that counts its KVC reads and writes, to verify which reads and writes skip KVC.
final class KVCCountingShapeLayer: CAShapeLayer {

  private(set) var kvcReadCount = 0

  private(set) var kvcWriteCount = 0

  override func value(forKeyPath keyPath: String) -> Any? {
    kvcReadCount += 1
    return super.value(forKeyPath: keyPath)
  }

  override func setValue(_ value: Any?, forKeyPath keyPath: String) {
    kvcWriteCount += 1
    super.setValue(value, forKeyPath: keyPath)
  }
}

/// A view whose backing layer counts its KVC reads and writes.
final class KVCCountingView: View {

  #if canImport(AppKit)
  override func makeBackingLayer() -> CALayer {
    KVCCountingLayer()
  }
  #endif

  #if canImport(UIKit)
  override static var layerClass: AnyClass {
    KVCCountingLayer.self
  }
  #endif
}
