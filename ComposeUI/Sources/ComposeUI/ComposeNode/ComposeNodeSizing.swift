//
//  ComposeNodeSizing.swift
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

import CoreGraphics

/// The sizing information of a compose node.
///
/// This data structure is used to describe the sizing behavior of a node in
/// both horizontal and vertical axes. The parent node of the node can use this
/// information to do a more efficient layout.
public struct ComposeNodeSizing: Hashable {

  /// The width sizing behavior.
  public let width: Sizing

  /// The height sizing behavior.
  public let height: Sizing

  /// The lengths of the container size that the layout read.
  ///
  /// `ComposeView` keeps a layout when it lays out the same content again at a container size that differs only in
  /// lengths that the layout didn't read, such as a list of rows of a fixed height at another height. A sizing that
  /// leaves out a length that the layout read can keep a layout made for another value of that length, so report every
  /// length that the layout reads, itself or through its child nodes. A node that returns its child's sizing passes on
  /// the child's dependence, so it adds the lengths that it reads itself. Debug builds lay out again where a layout
  /// would be kept at another size, and assert if the two layouts differ in sizing, in size, or in the bounds of their
  /// items.
  ///
  /// It isn't part of the sizing's equality, since two layouts that size a node the same way give the same sizing,
  /// whatever they read.
  public let dependence: Dependence

  /// Creates a sizing with the given width and height.
  ///
  /// - Parameters:
  ///   - width: The width sizing behavior.
  ///   - height: The height sizing behavior.
  ///   - dependence: The lengths of the container size that the layout read. The default value, both lengths, is
  ///     correct for any layout.
  public init(width: Sizing, height: Sizing, dependence: Dependence = [.width, .height]) {
    self.width = width
    self.height = height
    self.dependence = dependence
  }

  /// Returns whether two sizings have the same width and height sizing behaviors, whatever lengths their layouts read.
  public static func == (lhs: ComposeNodeSizing, rhs: ComposeNodeSizing) -> Bool {
    lhs.width == rhs.width && lhs.height == rhs.height
  }

  /// Hashes the width and height sizing behaviors, which are the sizing's equality.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(width)
    hasher.combine(height)
  }
}

public extension ComposeNodeSizing {

  /// The sizing behavior of a compose node.
  enum Sizing: Hashable {

    /// The sizing is fixed.
    ///
    /// Node always have a fixed size regardless of the container size.
    case fixed(CGFloat)

    /// The sizing is flexible.
    ///
    /// Node can grow or shrink to fit the container.
    case flexible

    /// The sizing is flexible with a range.
    ///
    /// Node can grow or shrink to fit the container within the given range.
    ///
    /// - Note: `min` must be less than `max`.
    /// - Note: `min` must be greater than or equal to 0. Use `fixed` if `min` and `max` are the same.
    case range(min: CGFloat, max: CGFloat)

    /// Normalizes the sizing and returns a valid sizing.
    ///
    /// - Note: If the sizing is invalid, the method will assert and normalize it to a valid sizing.
    ///
    /// - Returns: The normalized sizing.
    func normalized() -> Sizing {
      switch self {
      case .fixed(let size):
        if size < 0 {
          ComposeUI.assertFailure("fixed sizing must have a size greater than or equal to 0, got \(size)")
          return .fixed(0)
        }
        if size == .infinity {
          ComposeUI.assertFailure("fixed sizing must have a non-infinite size")
          return .flexible
        }
        return .fixed(size)
      case .flexible:
        return .flexible
      case .range(let min, let max):
        var min = min
        var max = max
        if min < 0 {
          ComposeUI.assertFailure("range sizing must have a min greater than or equal to 0, got \(min)")
          min = 0
        }
        if min >= max {
          ComposeUI.assertFailure("range sizing must have a min less than max, got \(min) and \(max)")
          // clamp the max to min
          max = min
        }

        if min == 0, max == .infinity {
          return .flexible
        }

        if min == max {
          return .fixed(min)
        }

        return .range(min: min, max: max)
      }
    }

    // MARK: - Combine

    /// The axis type.
    enum Axis {

      /// The main axis.
      case main

      /// The cross axis.
      case cross
    }

    /// Combine the sizing with another sizing along the given axis.
    ///
    /// For container compose nodes such as `VerticalStackNode`, it needs to combine the sizings of its children
    /// into a single sizing as its own sizing.
    ///
    /// For main axis, the sizings are combined by summing up the sizes.
    ///
    /// For cross axis, the sizings are combined by taking the maximum size.
    ///
    /// - Parameters:
    ///   - other: The other sizing to combine with.
    ///   - axis: The axis to combine the sizing along.
    /// - Returns: The combined sizing.
    func combine(with other: Sizing, axis: Sizing.Axis) -> Sizing {
      switch axis {
      case .main:
        return combineInMainAxis(with: other)
      case .cross:
        return combineInCrossAxis(with: other)
      }
    }

    private func combineInMainAxis(with other: Sizing) -> Sizing {
      switch (self, other) {
      case (.fixed(let size1), .fixed(let size2)):
        return .fixed(max(0, size1 + size2))
      case (.fixed(let size), .flexible),
           (.flexible, .fixed(let size)):
        if size <= 0 {
          return .flexible
        } else {
          return .range(min: size, max: .infinity)
        }
      case (.fixed(let size), .range(let min, let max)),
           (.range(let min, let max), .fixed(let size)):
        let adjustedMin = Swift.max(0, min + size)
        let adjustedMax = Swift.max(0, max + size)
        if adjustedMin == adjustedMax {
          // a negative `size` could make both min and max be the same (zero)
          return .fixed(adjustedMin)
        } else {
          return .range(min: adjustedMin, max: adjustedMax)
        }
      case (.flexible, .flexible):
        return .flexible
      case (.flexible, .range(let min, _)),
           (.range(let min, _), .flexible):
        if min == 0 {
          return .flexible
        } else {
          return .range(min: min, max: .infinity)
        }
      case (.range(let min1, let max1), .range(let min2, let max2)):
        return .range(min: min1 + min2, max: max1 + max2)
      }
    }

    private func combineInCrossAxis(with other: Sizing) -> Sizing {
      switch (self, other) {
      case (.fixed(let size1), .fixed(let size2)):
        return .fixed(max(size1, size2))
      case (.fixed(let size), .flexible),
           (.flexible, .fixed(let size)):
        if size == 0 {
          return .flexible
        } else {
          return .range(min: size, max: .infinity)
        }
      case (.fixed(let size), .range(let min, let max)),
           (.range(let min, let max), .fixed(let size)):
        if size >= max {
          // when size >= max
          // | ------------------------- |
          // |                          size
          // |
          // |     | --------------- |
          // |     min              max
          return .fixed(size)
        } else {
          // when min < size < max
          // | --------- |
          // |          size
          // |
          // |     | --------------- |
          // |     min              max

          // when size < min
          // | --------- |
          // |          size
          // |
          // |                 | --------------- |
          // |                 min              max
          return .range(min: Swift.max(size, min), max: max)
        }
      case (.flexible, .flexible):
        return .flexible
      case (.flexible, .range(let min, _)),
           (.range(let min, _), .flexible):
        // | -------------------------- ...
        // |
        // |     | --------------- |
        // |     min              max
        if min == 0 {
          return .flexible
        } else {
          return .range(min: min, max: .infinity)
        }
      case (.range(let min1, let max1), .range(let min2, let max2)):
        // case 1, no overlap
        // |  | --------------- |
        // | min              max
        // |
        // |                        | --------------- |
        // |                        min              max

        // case 2, overlap
        // |     | --------------- |
        // |     min              max
        // |
        // |                | --------------- |
        // |                min              max

        // case 3, overlap
        // |     | --------------- |
        // |     min              max
        // |
        // |          | ------ |
        // |         min      max
        return .range(min: max(min1, min2), max: max(max1, max2))
      }
    }
  }
}

public extension ComposeNodeSizing {

  /// The lengths of a container size that a layout read.
  ///
  /// For example, a node as wide as its container and as tall as its content at that width reads the width alone:
  ///
  /// ```swift
  /// mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
  ///   size = CGSize(width: containerSize.width, height: contentHeight(forWidth: containerSize.width))
  ///   return ComposeNodeSizing(width: .flexible, height: .fixed(size.height), dependence: .width)
  /// }
  /// ```
  ///
  /// A node that passes the container's lengths on to its child nodes also reads what their layouts read, which their
  /// sizings' `dependence` tells. A node that returns a child's sizing passes on the child's `dependence`, so a node that
  /// also reads the container size itself, such as to pick a child, adds the lengths it reads:
  ///
  /// ```swift
  /// mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
  ///   isTall = containerSize.height >= 600
  ///   let sizing = isTall
  ///     ? tall.layout(containerSize: containerSize, context: context)
  ///     : short.layout(containerSize: containerSize, context: context)
  ///   return ComposeNodeSizing(
  ///     width: sizing.width,
  ///     height: sizing.height,
  ///     dependence: sizing.dependence.union(.height)
  ///   )
  /// }
  /// ```
  struct Dependence: OptionSet, Hashable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    /// The layout read the container's width.
    public static let width = Dependence(rawValue: 1 << 0)

    /// The layout read the container's height.
    public static let height = Dependence(rawValue: 1 << 1)

    /// Returns whether two container sizes have the same lengths that the layout read, so that a layout at either gives
    /// the same result.
    ///
    /// - Parameters:
    ///   - size: A container size.
    ///   - other: Another container size.
    /// - Returns: Whether the sizes have the same lengths that the layout read.
    func isSame(_ size: CGSize, as other: CGSize) -> Bool {
      (!contains(.width) || size.width == other.width) && (!contains(.height) || size.height == other.height)
    }
  }
}

#if DEBUG && !COMPOSEUI_BENCHMARK
extension ComposeNodeSizing.Dependence {

  /// Whether a layout kept at another container size is checked against a new layout at that size. A test that counts
  /// the layouts that a kept layout saves turns it off.
  static var checksKeptLayouts = true

  /// Returns the message of the assertion that a kept layout differs from a new layout at another container size,
  /// which a node whose layout reads a length that its sizing's dependence leaves out causes.
  ///
  /// - Parameters:
  ///   - keptContainerSize: The container size of the kept layout.
  ///   - keptSize: The size of the kept layout.
  ///   - containerSize: The container size of the new layout.
  ///   - size: The size of the new layout.
  /// - Returns: The message.
  static func keptLayoutMismatchMessage(keptContainerSize: CGSize, keptSize: CGSize, containerSize: CGSize, size: CGSize) -> String {
    """
    a layout differs at a container size that differs only in lengths that its sizing's dependence leaves out: \
    \(keptSize) at \(keptContainerSize), and \(size) at \(containerSize). Report each length of the container size \
    that a layout reads in its sizing's dependence, including when a node returns a child's sizing.
    """
  }
}
#endif
