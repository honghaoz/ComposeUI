//
//  DefaultView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/30/26.
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

/// Makes the plain view of a view type.
enum DefaultView {

  /// Makes a view of the type with its frame set to the context's initial frame.
  ///
  /// - Parameters:
  ///   - type: The type of the view.
  ///   - context: The make context.
  /// - Returns: The new view.
  static func make(_ type: View.Type, _ context: RenderableMakeContext) -> View {
    let view: View
    if let initialFrame = context.initialFrame {
      view = type.init(frame: initialFrame)
    } else {
      view = type.init()
    }
    #if canImport(AppKit)
    if type == View.self {
      view.wantsLayer = true
    }
    #endif
    view.translatesAutoresizingMaskIntoConstraints = true // use frame-based layout
    return view
  }
}
