//
//  Themed.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/18/22.
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

public typealias ThemedColor = Themed<Color>

/// A type that represents a value that can be themed.
public struct Themed<T> {

  /// The value for light theme.
  public let light: T

  /// The value for dark theme.
  public let dark: T

  /// Creates a new themed value.
  ///
  /// - Parameters:
  ///   - light: The value for light theme.
  ///   - dark: The value for dark theme.
  public init(light: T, dark: T) {
    self.light = light
    self.dark = dark
  }

  /// Creates a new themed value with the same value for both light and dark themes.
  ///
  /// - Parameter value: The value to use for both light and dark themes.
  public init(_ value: T) {
    self.light = value
    self.dark = value
  }

  /// Resolves the value for the given theme.
  ///
  /// - Parameter theme: The theme to resolve the value for.
  /// - Returns: The resolved value.
  public func resolve(for theme: Theme) -> T {
    switch theme {
    case .light:
      return light
    case .dark:
      return dark
    }
  }
}

extension Themed: Equatable where T: Equatable {

  public static func == (lhs: Themed<T>, rhs: Themed<T>) -> Bool {
    return lhs.light == rhs.light && lhs.dark == rhs.dark
  }
}

extension Themed: Hashable where T: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(light)
    hasher.combine(dark)
  }
}
