//
//  ReplacedImageReleaseTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/26/26.
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

import ChouTiTest

@testable import ComposeUI

class ReplacedImageReleaseTests: XCTestCase {

  override func setUp() {
    super.setUp()

    // the images that earlier tests replaced go away first, so that each test counts only its own
    ReplacedImageRelease.Test.handOffReplacedImagesAndWait()
  }

  func test_releaseAfterCommit_image_freesItsPixelsOnTheQueueAfterTheHandOff() throws {
    // given: a replaced image that only the release holds
    let pixels = PixelReleaseRecorder()
    try ReplacedImageRelease.releaseAfterCommit(pixels.makeImage())

    // then: the image waits for the hand-off
    expect(ReplacedImageRelease.Test.replacedImageCount) == 1
    expect(pixels.isReleasedOnMainThread) == nil

    // when: handing the replaced images to the queue, as the observer does after a commit
    ReplacedImageRelease.Test.handOffReplacedImagesAndWait()

    // then: the queue freed the image's pixels, off the main thread
    expect(ReplacedImageRelease.Test.replacedImageCount) == 0
    expect(pixels.isReleasedOnMainThread) == false
  }

  func test_releaseAfterCommit_contentsOtherThanAnImage_leavesThemToTheCaller() {
    // given: contents that aren't an image, as an `NSImage` that a layer can show, and no contents
    weak var weakContents: NSImage?
    do {
      let contents = NSImage(size: NSSize(width: 1, height: 1))
      weakContents = contents

      // when: releasing them after the commit
      ReplacedImageRelease.releaseAfterCommit(contents)
      ReplacedImageRelease.releaseAfterCommit(nil)
    }

    // then: nothing waits for a hand-off, and the contents went away with their last owner
    expect(ReplacedImageRelease.Test.replacedImageCount) == 0
    expect(weakContents) == nil
  }

  func test_runLoop_handsTheReplacedImagesToTheQueueAfterTheCommit() throws {
    // given: a replaced image that only the release holds
    let pixels = PixelReleaseRecorder()
    try ReplacedImageRelease.releaseAfterCommit(pixels.makeImage())
    expect(ReplacedImageRelease.Test.replacedImageCount) == 1

    // when: the main run loop runs once, where Core Animation commits before the run loop waits or exits, and the
    // observer runs after it
    RunLoop.main.run(mode: .default, before: Date())

    // then: the observer handed the image to the queue, which frees its pixels off the main thread
    expect(ReplacedImageRelease.Test.replacedImageCount) == 0
    ReplacedImageRelease.Test.handOffReplacedImagesAndWait()
    expect(pixels.isReleasedOnMainThread) == false
  }
}

#endif
