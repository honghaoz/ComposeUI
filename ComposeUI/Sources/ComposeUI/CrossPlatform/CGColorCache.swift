//
//  CGColorCache.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/26.
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

/// The `CGColor`s of the colors that layers show.
///
/// AppKit makes a new `CGColor`, with an allocation and color space work, each time a color held in a tagged pointer is
/// read, so the main thread keeps the `CGColor`s of the component-based colors read last. UIKit keeps a static color's
/// `CGColor` in the color, and a dynamic color's follows the trait collection, so on UIKit the cache passes on the
/// color's own.
enum CGColorCache {

  /// Returns the color's `CGColor`.
  ///
  /// - Parameter color: The color.
  /// - Returns: The `CGColor`.
  static func cgColor(of color: Color) -> CGColor {
    #if canImport(AppKit)
    guard Thread.isMain else {
      return color.cgColor
    }

    let entry = entries + index(of: color)
    switch entry.pointee {
    case .some(let cached) where cached.color === color:
      return cached.cgColor
    case .some,
         .none:
      let cgColor = color.cgColor
      // a component-based color always makes an equal `CGColor`, while a catalog color's follows the appearance and a
      // pattern color's follows its image, so only a component-based color is kept. the entry keeps the color, so that
      // no other color takes its address while the entry matches it
      if color.type == .componentBased {
        entry.pointee = Entry(color: color, cgColor: cgColor)
      }
      return cgColor
    }
    #else
    return color.cgColor
    #endif
  }

  #if canImport(AppKit)

  /// A color and its `CGColor`.
  private struct Entry {

    let color: NSColor
    let cgColor: CGColor
  }

  /// The entries, by the index of their colors.
  ///
  /// The cache manages the memory instead of keeping an array, so that the compiler doesn't check each access at run
  /// time.
  private static let entries: UnsafeMutablePointer<Entry?> = {
    let pointer = UnsafeMutablePointer<Entry?>.allocate(capacity: Constants.entryCount)
    pointer.initialize(repeating: nil, count: Constants.entryCount)
    return pointer
  }()

  /// Returns the index of a color's entry.
  private static func index(of color: NSColor) -> Int {
    // multiplying by the golden ratio spreads the bits of a tagged pointer's components and of an object's address,
    // whose low bits are always the same, over the top bits that the index takes
    let bits = UInt(bitPattern: ObjectIdentifier(color)) &* Constants.multiplier
    return Int(bits >> (UInt.bitWidth - Constants.indexBitCount))
  }

  // MARK: - Constants

  private enum Constants {

    /// The number of bits of an entry's index.
    static let indexBitCount = 5

    /// The number of entries, more than the colors that a render pass usually sets, so that its colors rarely take
    /// each other's entries.
    static let entryCount = 1 << indexBitCount

    /// 2^64 divided by the golden ratio, odd so that multiplying by it maps distinct values to distinct values.
    static let multiplier: UInt = 0x9E3779B97F4A7C15
  }

  #if DEBUG

  // MARK: - Testing

  /// Returns the `CGColor` that the cache keeps for a color, `nil` if it keeps none.
  static func keptCGColorForTesting(of color: NSColor) -> CGColor? {
    switch entries[index(of: color)] {
    case .some(let entry) where entry.color === color:
      return entry.cgColor
    case .some,
         .none:
      return nil
    }
  }

  /// Returns the index of a color's entry.
  static func entryIndexForTesting(of color: NSColor) -> Int {
    index(of: color)
  }

  #endif

  #endif
}
