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
    SwiftUISizingHostPool.shared.sizeThatFits(self, in: proposingSize)
  }
}

#if canImport(AppKit)
private typealias HostingController = NSHostingController
#endif

#if canImport(UIKit)
private typealias HostingController = UIHostingController
#endif

/// A pool of `HostingController` instances used to measure SwiftUI views, to avoid per-call `HostingController` allocation cost.
///
/// A pool (rather than a single shared host) is used so that reentrant calls, e.g. a parent view's body calls `sizeThatFits` on a child
/// while the parent itself is being measured, each get their own dedicated host controller.
///
/// The pool grows lazily to match the deepest observed reentrancy and stays at that size afterwards.
@MainActor
private final class SwiftUISizingHostPool {

  static let shared = SwiftUISizingHostPool()

  private var hosts: [HostingController<AnyView>] = []

  private init() {}

  func sizeThatFits(_ view: some SwiftUI.View, in proposingSize: CGSize) -> CGSize {
    let host = hosts.popLast() ?? HostingController(rootView: AnyView(EmptyView()))
    host.rootView = AnyView(view)
    defer {
      // drop the reference to the user's view before returning the host to the pool.
      host.rootView = AnyView(EmptyView())
      hosts.append(host)
    }
    return host.sizeThatFits(in: proposingSize)
  }
}
