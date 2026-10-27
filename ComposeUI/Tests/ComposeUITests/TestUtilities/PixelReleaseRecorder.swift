//
//  PixelReleaseRecorder.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/26/26.
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

import ChouTiTest
import CoreGraphics

@testable import ComposeUI

/// Records the thread that frees the pixels of an image that it makes, which tests read to tell where the image went
/// away.
final class PixelReleaseRecorder {

  /// Whether the main thread freed the pixels, `nil` until they're freed.
  private(set) var isReleasedOnMainThread: Bool?

  /// Makes a 1 by 1 image whose pixels the recorder records the release of.
  ///
  /// - Returns: The image.
  func makeImage() throws -> CGImage {
    let bytes = UnsafeMutableRawPointer.allocate(byteCount: 4, alignment: 4)
    bytes.initializeMemory(as: UInt8.self, repeating: 0, count: 4)
    // the provider keeps the recorder until it frees the pixels, which it does when the image goes away
    let info = Unmanaged.passRetained(self).toOpaque()
    let provider = try unwrap(
      CGDataProvider(dataInfo: info, data: bytes, size: 4) { info, data, _ in
        UnsafeMutableRawPointer(mutating: data).deallocate()
        guard let info else {
          return
        }
        Unmanaged<PixelReleaseRecorder>.fromOpaque(info).takeRetainedValue().isReleasedOnMainThread = Thread.isMain
      }
    )
    return try unwrap(
      CGImage(
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    )
  }
}
