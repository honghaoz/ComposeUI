//
//  PathsForSizesTests.swift
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

import ChouTiTest

@testable import ComposeUI

final class PathsForSizesTests: XCTestCase {

  func test_paths_makesEachSizeOnce() {
    // given: paths for sizes that are the sizes themselves, and the three sizes an update asks for at most
    var pathsForSizes = PathsForSizes<CGSize>()
    var madeSizes: [CGSize] = []
    func paths(for size: CGSize) -> CGSize {
      pathsForSizes.paths(for: size) { size in
        madeSizes.append(size)
        return size
      }
    }
    let sizes = [CGSize(width: 1, height: 1), CGSize(width: 2, height: 2), CGSize(width: 3, height: 3)]

    // when: asking for each size twice
    let askedPaths = (sizes + sizes).map(paths(for:))

    // then: the paths are each size's, made once
    expect(askedPaths) == sizes + sizes
    expect(madeSizes) == sizes

    // when: asking for a fourth size, then for the third size and the first two again
    let fourthSize = CGSize(width: 4, height: 4)
    let laterSizes = [fourthSize, sizes[2], sizes[0], sizes[1]]
    let laterPaths = laterSizes.map(paths(for:))

    // then: the fourth size took the third size's slot, so the third size's paths are made again, while the first two
    // sizes keep theirs
    expect(laterPaths) == laterSizes
    expect(madeSizes) == sizes + [fourthSize, sizes[2]]
  }
}
