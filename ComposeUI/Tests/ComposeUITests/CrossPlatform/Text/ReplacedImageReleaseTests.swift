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

  func test_releaseAfterCommit_withoutTheRunLoop_handsTheImagesOffAtABound() throws {
    // given: replaced images of a quarter of the bound's bytes each, in a host that commits without turning the run
    // loop, such as one that renders snapshots, where the observer doesn't run
    let bound = ReplacedImageRelease.Test.replacedImageBytesToHandOff
    let width = 1024
    let height = bound / 4 / (width * 4)
    let recorders = (0 ..< 13).map { _ in PixelReleaseRecorder() }

    // when: releasing each image after the commit
    for pixels in recorders {
      try ReplacedImageRelease.releaseAfterCommit(pixels.makeImage(width: width, height: height))

      // then: the bytes that wait for a hand-off stay below the bound
      expect(ReplacedImageRelease.Test.replacedImageBytes) < bound
    }

    // then: each fourth image handed the images off to the queue, which freed their pixels off the main thread, and the
    // last image waits for the next hand-off
    ReplacedImageRelease.Test.waitForReleases()
    expect(recorders.filter { $0.isReleasedOnMainThread == false }.count) == 12
    expect(recorders.last?.isReleasedOnMainThread) == nil
    expect(ReplacedImageRelease.Test.replacedImageCount) == 1
  }

  func test_releaseAfterCommit_offTheMainThread_asserts() {
    // given: a test assertion failure handler
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: releasing contents after the commit on another thread
    onNewThread {
      ReplacedImageRelease.releaseAfterCommit(nil)
    }

    // then: it asserts that the release runs on the main thread
    expect(assertionMessages) == ["releaseAfterCommit(_:) must be called on the main thread"]
  }

  func test_observer_runsAfterCoreAnimationsCommit() throws {
    // given: the main run loop's observers, after a layer change installs Core Animation's commit observer, and a
    // replaced image installs the release's
    let layer = CALayer()
    layer.opacity = 0.5
    try ReplacedImageRelease.releaseAfterCommit(PixelReleaseRecorder().makeImage())
    let commitObserver = try unwrap(Self.coreAnimationCommitObserver())

    // then: the release's observer runs after Core Animation's commit, in each run loop activity that Core Animation
    // commits in
    expect(try unwrap(ReplacedImageRelease.Test.observerOrder)) > commitObserver.order
    expect(try unwrap(ReplacedImageRelease.Test.observerActivities) & commitObserver.activities) == commitObserver.activities
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

  // MARK: - Helpers

  /// Returns the order and the activities of Core Animation's commit observer on the main run loop, `nil` if the main
  /// run loop has none.
  ///
  /// They're read from the run loop's description, since no API lists a run loop's observers.
  private static func coreAnimationCommitObserver() -> (order: CFIndex, activities: CFOptionFlags)? {
    let description = CFCopyDescription(CFRunLoopGetMain()) as String
    let pattern = "activities = 0x([0-9a-f]+)[^}]*?order = (-?[0-9]+), callout = [^,(]*CA11Transaction17observer_callback"
    guard let match = try? NSRegularExpression(pattern: pattern).firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
          let activitiesRange = Range(match.range(at: 1), in: description),
          let orderRange = Range(match.range(at: 2), in: description),
          let activities = CFOptionFlags(description[activitiesRange], radix: 16),
          let order = CFIndex(description[orderRange])
    else {
      return nil
    }
    return (order, activities)
  }
}

#endif
