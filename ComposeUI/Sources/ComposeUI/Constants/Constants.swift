//
//  Constants.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/20/25.
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

public enum Constants {

  #if canImport(UIKit)
  /// The default duration of a press gesture.
  public static let defaultPressDuration: TimeInterval = 0.5
  #elseif canImport(AppKit)
  /// The default duration of a press gesture.
  public static let defaultPressDuration: TimeInterval = NSEvent.doubleClickInterval
  #endif

  #if canImport(UIKit)
  /// The default duration of a double-tap event.
  public static let defaultDoubleTapDuration: TimeInterval = 0.15
  #elseif canImport(AppKit)
  /// The default duration of a double-click event.
  public static let defaultDoubleTapDuration: TimeInterval = NSEvent.doubleClickInterval
  #endif

  /// The default scale factor for the UI.
  static let defaultScaleFactor: CGFloat = 2.0
}
