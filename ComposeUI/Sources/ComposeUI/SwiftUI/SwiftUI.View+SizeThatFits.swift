//
//  SwiftUI.View+SizeThatFits.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/3/21.
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

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

public extension SwiftUI.View {

  /// Get a fitting size based on the proposing size.
  ///
  /// - Parameters:
  ///   - proposingSize: The proposing container size.
  /// - Returns: The fitting size of the view.
  func sizeThatFits(_ proposingSize: CGSize) -> CGSize {
    #if canImport(AppKit)
    var computedSize: CGSize?

    let semaphore = DispatchSemaphore(value: 0)
    let sizeComputingView = onSizeChange { newSize in
      computedSize = newSize
      semaphore.signal()
    }
    let hostingView = NSHostingView(rootView: sizeComputingView)
    hostingView.frame = CGRect(origin: .zero, size: proposingSize)

    hostingView.setNeedsLayout()
    hostingView.layoutIfNeeded()

    semaphore.wait()
    return computedSize.assertNotNil("computedSize should not be nil") ?? .zero
    #endif

    #if canImport(UIKit)
    return UIHostingController(rootView: self).sizeThatFits(in: proposingSize)
    #endif
  }
}

#if canImport(AppKit)
private struct SizePreferenceKey: PreferenceKey {
  static let defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

private extension SwiftUI.View {

  func onSizeChange(_ onChangeClosure: @escaping (CGSize) -> Void) -> some SwiftUI.View {
    background(
      GeometryReader { proxy in
        SwiftUI.Rectangle()
          .preference(key: SizePreferenceKey.self, value: proxy.size)
      }
    )
    .onPreferenceChange(SizePreferenceKey.self, perform: onChangeClosure)
  }
}
#endif
