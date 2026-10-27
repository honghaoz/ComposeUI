//
//  ReplacedImageRelease.swift
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

import AppKit

/// Releases the images that layers replace on a background thread, after Core Animation commits the transaction that
/// replaced them.
///
/// A layer keeps its replaced contents until the transaction commits, and an image that loses its last owner then frees
/// its pixels on the main thread, which for a label's image takes a kernel call.
///
/// It's used on the main thread, while `queue` releases the images that the main thread hands it.
enum ReplacedImageRelease {

  /// Releases a layer's replaced contents on a background thread after Core Animation's next commit, if they're an image.
  ///
  /// An image that `queue` releases before the commit, such as when the run loop doesn't run before a later commit,
  /// stays with Core Animation until that commit, and is freed there, as it would be without this.
  ///
  /// - Parameter contents: The layer's contents before it replaced them.
  static func releaseAfterCommit(_ contents: Any?) {
    ComposeUI.assert(Thread.isMain, "releaseAfterCommit(_:) must be called on the main thread")

    // other contents, such as a backing store that Core Animation made for the layer's drawing, stay with Core Animation
    guard let contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID else {
      return
    }
    let image = unsafeDowncast(contents as AnyObject, to: CGImage.self)
    replacedImages.append(image)
    replacedImageBytes += image.bytesPerRow * image.height
    if observer == nil {
      observer = makeObserver()
    }

    // a host that commits without turning the run loop, such as one that renders snapshots, never runs the observer,
    // so the images are handed off at a bound of their bytes instead of piling up. Core Animation keeps an image until
    // its commit, which frees an image handed off before it on the main thread, as without the release, but only a
    // frame that replaces more than the bound hands images off before their commit
    if replacedImageBytes >= Constants.replacedImageBytesToHandOff {
      handOffReplacedImages()
    }
  }

  /// The images that the main thread replaced since the observer last ran.
  private static var replacedImages: [CGImage] = []

  /// The bytes of the images in `replacedImages`.
  private static var replacedImageBytes = 0

  /// The observer of the main run loop that hands the replaced images to `queue`, made with the first image.
  private static var observer: CFRunLoopObserver?

  /// The queue that releases the images that the main thread hands it.
  private static let queue = DispatchQueue(label: "com.honghaoz.ComposeUI.ReplacedImageRelease", qos: .utility)

  /// Makes the observer that hands the replaced images to `queue` after Core Animation's commit, and adds it to the
  /// main run loop.
  private static func makeObserver() -> CFRunLoopObserver {
    let observer: CFRunLoopObserver = CFRunLoopObserverCreateWithHandler(
      kCFAllocatorDefault,
      CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue,
      true,
      Constants.observerOrder,
      { _, _ in
        handOffReplacedImages()
      }
    )
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    return observer
  }

  /// Hands the replaced images to `queue`, which releases them.
  private static func handOffReplacedImages() {
    guard !replacedImages.isEmpty else {
      return
    }

    // the images move to a batch that only its block changes, and the main thread lets go of them before it queues the
    // block, so the block's emptying of the batch releases each image on the queue, whichever thread releases the
    // batch itself last
    let batch = Batch(images: replacedImages)
    // the array keeps its capacity, in a buffer of its own, so that the next replaced images append without allocating
    replacedImages.removeAll(keepingCapacity: true)
    replacedImageBytes = 0

    queue.asyncWithoutFlags {
      batch.images.removeAll()
    }
  }

  /// The images of a hand-off, which only the block that releases them changes.
  private final class Batch {

    /// The images, which the block that releases them empties.
    var images: [CGImage]

    init(images: [CGImage]) {
      self.images = images
    }
  }

  // MARK: - Testing

  #if DEBUG
  enum Test {

    /// The number of replaced images that the main thread hasn't handed to the queue.
    static var replacedImageCount: Int {
      replacedImages.count
    }

    /// The bytes of the replaced images that the main thread hasn't handed to the queue.
    static var replacedImageBytes: Int {
      ReplacedImageRelease.replacedImageBytes
    }

    /// The bytes of replaced images at which the main thread hands them to the queue without waiting for the observer.
    static var replacedImageBytesToHandOff: Int {
      Constants.replacedImageBytesToHandOff
    }

    /// The order of the observer that hands the replaced images to the queue, `nil` before the first image makes it.
    static var observerOrder: CFIndex? {
      observer.map(CFRunLoopObserverGetOrder)
    }

    /// The run loop activities that the observer runs in, `nil` before the first image makes it.
    static var observerActivities: CFOptionFlags? {
      observer.map(CFRunLoopObserverGetActivities)
    }

    /// Hands the replaced images to the queue, as the observer does after a commit, and waits until the queue releases
    /// them.
    static func handOffReplacedImagesAndWait() {
      handOffReplacedImages()
      waitForReleases()
    }

    /// Waits until the queue releases the images that the main thread handed it.
    static func waitForReleases() {
      queue.sync {}
    }
  }
  #endif

  // MARK: - Constants

  private enum Constants {

    /// The bytes of replaced images at which the main thread hands them to the queue without waiting for the observer,
    /// which bounds the images that a host that doesn't turn the run loop keeps.
    ///
    /// Scrolling the benchmarks' nested rows by a full screen in one frame replaces 1.2 MB of label images in a window of
    /// 390 by 844 points at a scale of 2, about a quarter of the window's pixels, which in a full-screen window on a 6K
    /// display would be about 20 MB, so an app's frames stay below the bound.
    static let replacedImageBytesToHandOff = 64 * 1024 * 1024

    /// The order of the observer, after Core Animation's commit observer, which has order 2,000,000, and commits the
    /// main thread's transaction before the run loop waits and when it exits, as the observer runs.
    static let observerOrder: CFIndex = 2000001
  }
}

#endif
