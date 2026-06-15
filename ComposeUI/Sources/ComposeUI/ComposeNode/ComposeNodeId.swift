//
//  ComposeNodeId.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

enum StandardComposeNodeId: String {

  case empty = "E"

  case color = "C"
  case label = "TL" // text label
  case textView = "TV" // text view
  case button = "B"
  case view = "V"
  case layer = "L"
  case swiftui = "SUI"
  case gesture = "G"

  case dropShadow = "DS"
  case innerShadow = "IS"

  case spacer = "S"
  case frame = "F"
  case padding = "P"
  case offset = "O"

  case overlay = "OV"
  case underlay = "UL"
  case vStack = "VS"
  case hStack = "HS"
  case zStack = "ZS"
  case composeView = "CV"
}

public struct ComposeNodeId: Hashable {

  /// Create a custom id for a node.
  ///
  /// - Parameters:
  ///   - id: The id string. You should ensure the id is unique.
  ///   - isFixed: If the id is fixed.
  /// - Returns: A `ComposeNodeId`.
  public static func custom(_ id: String, isFixed: Bool = false) -> ComposeNodeId {
    guard StandardComposeNodeId(rawValue: id) == nil else {
      ComposeUI.assertFailure("[ComposeUI] Custom id conflict with standard id: \(id), please use a unique id.")
      return ComposeNodeId(id: "\(id)-\(UUID().uuidString)", isFixed: isFixed)
    }
    return ComposeNodeId(id: id, isFixed: isFixed)
  }

  /// Create a standard id for a node.
  static func standard(_ id: StandardComposeNodeId) -> ComposeNodeId {
    ComposeNodeId(id: id.rawValue, isFixed: false)
  }

  /// The id of the node.
  public let id: String

  /// If the id is fixed.
  ///
  /// If the id is fixed, `join` will not add the parent node's id to the child node's id.
  private let isFixed: Bool

  /// A precomputed 64-bit hash of `id`.
  ///
  /// `ComposeView` uses node ids as render-pass dictionary/set keys. Caching this value keeps dictionary probes from
  /// repeatedly hashing long composed id strings, while equality still checks the exact string so collisions remain safe.
  private let cachedHash: UInt64

  private init(id: String, isFixed: Bool) {
    self.id = id
    self.isFixed = isFixed
    self.cachedHash = Self.fnv1a(id)
  }

  private init(id: String, isFixed: Bool, cachedHash: UInt64) {
    self.id = id
    self.isFixed = isFixed
    self.cachedHash = cachedHash
  }

  // MARK: - Hashable

  public func hash(into hasher: inout Hasher) {
    hasher.combine(cachedHash)
  }

  public static func == (lhs: ComposeNodeId, rhs: ComposeNodeId) -> Bool {
    // A node id's identity is its composed `id` string. `isFixed` only controls how the id is composed (whether a parent
    // prefix is added in `join`), not which item the id denotes, so it is intentionally excluded from equality. This
    // matches the render diff's long-standing behavior of keying its maps by the id string only: a `fixedId("x")` item
    // and a composed item that resolves to "x" are the same (conflicting) render item, not two distinct ones.
    //
    // The cheap precomputed hash is compared first to reject mismatches without touching the strings; the exact `id`
    // compare then makes equality collision-free (two distinct ids that happen to share a hash are never treated equal).
    lhs.cachedHash == rhs.cachedHash && lhs.id == rhs.id
  }

  func isSameConfiguration(as other: ComposeNodeId) -> Bool {
    id == other.id && isFixed == other.isFixed
  }

  /// FNV-1a hash of the string's UTF-8 bytes.
  ///
  /// Used to derive `cachedHash` from `id`, so the same `id` always yields the same hash regardless of how it was
  /// composed (keeping `Hashable` consistent with the exact `==`).
  @inline(__always)
  private static func fnv1a(_ string: String) -> UInt64 {
    fnv1a(string, hash: HashConstants.fnvOffsetBasis)
  }

  @inline(__always)
  private static func fnv1a(_ string: String, hash initialHash: UInt64) -> UInt64 {
    var hash = initialHash
    for byte in string.utf8 {
      hash = fnv1a(byte, hash: hash)
    }
    return hash
  }

  @inline(__always)
  private static func fnv1a(_ byte: UInt8, hash: UInt64) -> UInt64 {
    (hash ^ UInt64(byte)) &* HashConstants.fnvPrime
  }

  /// Make a `ComposeNodeId` by joining the current node's id with a child node's id.
  ///
  /// If the `childNodeId` is fixed, it will return the `childNodeId` directly.
  ///
  /// - Parameters:
  ///   - childNodeId: The child node's id.
  ///   - suffix: An optional suffix to be added to the current node's id.
  /// - Returns: A `ComposeNodeId`.
  public func join(with childNodeId: ComposeNodeId, suffix: String? = nil) -> ComposeNodeId {
    if childNodeId.isFixed {
      return childNodeId
    } else {
      if let suffix {
        var hash = Self.fnv1a(HashConstants.separator, hash: cachedHash)
        hash = Self.fnv1a(suffix, hash: hash)
        hash = Self.fnv1a(HashConstants.separator, hash: hash)
        hash = Self.fnv1a(childNodeId.id, hash: hash)
        return ComposeNodeId(id: "\(id)|\(suffix)|\(childNodeId.id)", isFixed: isFixed, cachedHash: hash)
      } else {
        var hash = Self.fnv1a(HashConstants.separator, hash: cachedHash)
        hash = Self.fnv1a(childNodeId.id, hash: hash)
        return ComposeNodeId(id: "\(id)|\(childNodeId.id)", isFixed: isFixed, cachedHash: hash)
      }
    }
  }
}

// MARK: - Constants

private enum HashConstants {

  static let separator: UInt8 = 0x7C // "|"
  static let fnvOffsetBasis: UInt64 = 0xCBF29CE484222325
  static let fnvPrime: UInt64 = 0x00000100000001B3
}
