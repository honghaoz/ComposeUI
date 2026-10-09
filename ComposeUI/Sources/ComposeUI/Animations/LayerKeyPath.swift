//
//  LayerKeyPath.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/9/26.
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

/// The key paths the framework passes to Core Animation, made from Objective-C strings.
///
/// Swift copies a string of up to 15 bytes into a new Objective-C string each time it passes the string to an
/// Objective-C method, unless the string fits in a tagged pointer, while a string made from an Objective-C string is
/// passed as that string. The framework's switches compare key paths fastest as such short Swift strings, so the
/// framework keeps its key paths as they are written and looks up the Objective-C string only to pass a key path to
/// Core Animation.
enum LayerKeyPath {

  /// Returns the key path to pass to Core Animation.
  ///
  /// - Parameter keyPath: The key path.
  /// - Returns: The key path made from an Objective-C string, for a key path the framework animates that Swift would
  ///   copy, otherwise `keyPath`.
  static func objectiveC(_ keyPath: String) -> String {
    // Swift passes a string of more than 15 bytes as it is, and Foundation fits the shorter key paths the framework
    // animates in tagged pointers, so the strings are compared only for key paths of the lengths Swift would copy
    guard (Constants.shortestLength ... Constants.longestCopiedLength).contains(keyPath.utf8.count) else {
      return keyPath
    }

    switch keyPath {
    case "backgroundColor":
      return Constants.backgroundColor
    case "bounds.size":
      return Constants.boundsSize
    case "borderColor":
      return Constants.borderColor
    case "borderWidth":
      return Constants.borderWidth
    case "cornerRadius":
      return Constants.cornerRadius
    case "shadowColor":
      return Constants.shadowColor
    case "shadowOpacity":
      return Constants.shadowOpacity
    case "shadowRadius":
      return Constants.shadowRadius
    case "shadowOffset":
      return Constants.shadowOffset
    case "shadowPath":
      return Constants.shadowPath
    case "transform.scale":
      return Constants.transformScale
    default:
      return keyPath
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The length, in bytes, of the shortest key path in the lookup.
    static let shortestLength = 10

    /// The length, in bytes, of the longest string that Swift copies when it passes the string to Objective-C.
    static let longestCopiedLength = 15

    static let backgroundColor = make("backgroundColor")
    static let boundsSize = make("bounds.size")
    static let borderColor = make("borderColor")
    static let borderWidth = make("borderWidth")
    static let cornerRadius = make("cornerRadius")
    static let shadowColor = make("shadowColor")
    static let shadowOpacity = make("shadowOpacity")
    static let shadowRadius = make("shadowRadius")
    static let shadowOffset = make("shadowOffset")
    static let shadowPath = make("shadowPath")
    static let transformScale = make("transform.scale")

    /// Makes a key path from an Objective-C string.
    ///
    /// - Parameter keyPath: The key path.
    /// - Returns: The key path, made from an Objective-C string.
    private static func make(_ keyPath: String) -> String {
      keyPath as NSString as String
    }
  }
}
