//
//  PathsForSizes.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

/// The paths an update of a layer makes for the sizes its paths ask for, each made once, for a layer that sets several
/// paths from the same paths, as a shadow layer does.
///
/// A path that follows the layer's size asks for the layer's size, and after a resize for the size the current path was
/// made for and the new width with the old height too, see `CALayer.animatePath(keyPath:timing:resizingFrom:to:)`. So an
/// update asks for at most three sizes, which take a slot each, without allocating.
struct PathsForSizes<Paths> {

  private var first: (size: CGSize, paths: Paths)?
  private var second: (size: CGSize, paths: Paths)?
  private var third: (size: CGSize, paths: Paths)?

  /// The paths for a size, made the first time the size is asked for.
  ///
  /// - Parameters:
  ///   - size: The size.
  ///   - make: The paths for a size.
  /// - Returns: The paths.
  mutating func paths(for size: CGSize, make: (CGSize) -> Paths) -> Paths {
    if let first, first.size == size {
      return first.paths
    }
    if let second, second.size == size {
      return second.paths
    }
    if let third, third.size == size {
      return third.paths
    }

    let paths = make(size)
    // a size past the third, which a layer's paths don't ask for, takes the third slot, so its paths are made again if
    // asked for after another
    if first == nil {
      first = (size, paths)
    } else if second == nil {
      second = (size, paths)
    } else {
      third = (size, paths)
    }
    return paths
  }
}
