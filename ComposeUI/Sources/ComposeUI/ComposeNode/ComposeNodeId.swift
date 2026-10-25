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

@usableFromInline
enum StandardComposeNodeId: Int, CaseIterable {

  case empty

  case color
  case label
  case textView
  case button
  case view
  case layer
  case swiftui
  case gesture

  case dropShadow
  case innerShadow

  case spacer
  case frame
  case padding
  case offset

  case overlay
  case underlay
  case vStack
  case hStack
  case zStack
  case composeView

  /// The id string.
  var string: String {
    switch self {
    case .empty:
      return "E"
    case .color:
      return "C"
    case .label:
      return "TL" // text label
    case .textView:
      return "TV" // text view
    case .button:
      return "B"
    case .view:
      return "V"
    case .layer:
      return "L"
    case .swiftui:
      return "SUI"
    case .gesture:
      return "G"
    case .dropShadow:
      return "DS"
    case .innerShadow:
      return "IS"
    case .spacer:
      return "S"
    case .frame:
      return "F"
    case .padding:
      return "P"
    case .offset:
      return "O"
    case .overlay:
      return "OV"
    case .underlay:
      return "UL"
    case .vStack:
      return "VS"
    case .hStack:
      return "HS"
    case .zStack:
      return "ZS"
    case .composeView:
      return "CV"
    }
  }
}

public struct ComposeNodeId: Hashable {

  /// Create a custom id for a node.
  ///
  /// - Parameters:
  ///   - id: The id string. You should ensure the id is unique.
  ///   - isFixed: If the id is fixed.
  /// - Returns: A `ComposeNodeId`.
  public static func custom(_ id: String, isFixed: Bool = false) -> ComposeNodeId {
    guard !standardIdStrings.contains(id) else {
      ComposeUI.assertFailure("[ComposeUI] Custom id conflict with standard id: \(id), please use a unique id.")
      return ComposeNodeId(id: "\(id)-\(UUID().uuidString)", isFixed: isFixed)
    }
    return ComposeNodeId(id: id, isFixed: isFixed)
  }

  /// Create a standard id for a node.
  @usableFromInline
  static func standard(_ id: StandardComposeNodeId) -> ComposeNodeId {
    // the hashes are computed once instead of for each node, and the strings stay literals, which need no retain, unlike
    // strings read from a table of ids
    ComposeNodeId(id: id.string, isFixed: false, cachedHash: standardHashes[id.rawValue])
  }

  /// Creates the id of a node that shows an object, unique to the object while it lives.
  ///
  /// - Parameters:
  ///   - object: The object.
  ///   - kind: The standard id of the node's kind, which tells the ids of different kinds of node apart.
  /// - Returns: The id.
  static func object(_ object: AnyObject, kind: StandardComposeNodeId) -> ComposeNodeId {
    // the address in base 36 after the kind's short code fits in a small string, which takes no allocation, while
    // describing the object identifier takes several, and makes each id that a parent joins with it long as well
    ComposeNodeId(id: kind.string + ":" + String(UInt(bitPattern: ObjectIdentifier(object)), radix: 36), isFixed: false)
  }

  /// The hashes of the standard ids' strings, each at its case's raw value.
  private static let standardHashes = StandardComposeNodeId.allCases.map { fnv1a($0.string) }

  /// The strings of the standard ids, which custom ids can't use.
  private static let standardIdStrings = Set(StandardComposeNodeId.allCases.map(\.string))

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
      var parentId = id
      var childId = childNodeId.id
      return parentId.withUTF8 { parentBytes in
        childId.withUTF8 { childBytes in
          if var suffix {
            return suffix.withUTF8 { suffixBytes in
              joinedId(parent: parentBytes, suffix: suffixBytes, child: childBytes)
            }
          } else {
            return joinedId(parent: parentBytes, suffix: nil, child: childBytes)
          }
        }
      }
    }
  }

  /// Returns the id of this id's bytes, a suffix's bytes, if any, and a child id's bytes, with a separator between each.
  @inline(__always)
  private func joinedId(parent parentBytes: UnsafeBufferPointer<UInt8>,
                        suffix suffixBytes: UnsafeBufferPointer<UInt8>?,
                        child childBytes: UnsafeBufferPointer<UInt8>) -> ComposeNodeId
  {
    // interpolating the pieces re-encodes the string at each piece that it appends, which took most of a join's time,
    // so the joined id is written once at its length, with its hash going on over each byte as it's copied
    let count = parentBytes.count + 1 + (suffixBytes.map { $0.count + 1 } ?? 0) + childBytes.count
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: count) { buffer in
      var index = 0
      for byte in parentBytes {
        buffer[index] = byte
        index += 1
      }

      // this id's hash covers its bytes, so the hash goes on from the separator after them
      var hash = cachedHash
      Self.write(HashConstants.separator, into: buffer, at: &index, hash: &hash)
      if let suffixBytes {
        for byte in suffixBytes {
          Self.write(byte, into: buffer, at: &index, hash: &hash)
        }
        Self.write(HashConstants.separator, into: buffer, at: &index, hash: &hash)
      }
      for byte in childBytes {
        Self.write(byte, into: buffer, at: &index, hash: &hash)
      }

      // the bytes come from strings, which hold valid UTF-8, so decoding them has nothing to repair, while the failable
      // `String(bytes:encoding:)` that the rule prefers goes through `NSString`
      // swiftlint:disable:next optional_data_string_conversion
      return ComposeNodeId(id: String(decoding: UnsafeBufferPointer(buffer), as: UTF8.self), isFixed: isFixed, cachedHash: hash)
    }
  }

  /// Writes a byte into a buffer at an index, moves the index past it, and goes on with a hash over it.
  @inline(__always)
  private static func write(_ byte: UInt8, into buffer: UnsafeMutableBufferPointer<UInt8>, at index: inout Int, hash: inout UInt64) {
    buffer[index] = byte
    index += 1
    hash = fnv1a(byte, hash: hash)
  }
}

// MARK: - Constants

private enum HashConstants {

  static let separator: UInt8 = 0x7C // "|"
  static let fnvOffsetBasis: UInt64 = 0xCBF29CE484222325
  static let fnvPrime: UInt64 = 0x00000100000001B3
}
