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
    replacedImages.append(contents as AnyObject)
    if observer == nil {
      observer = makeObserver()
    }

    // a host that commits without turning the run loop, such as one that renders snapshots, never runs the observer,
    // so the images are handed off at a bound instead of piling up, which is safe before their commit, since Core
    // Animation keeps an image until then
    if replacedImages.count >= Constants.replacedImageCountToHandOff {
      handOffReplacedImages()
    }
  }

  /// The images that the main thread replaced since the observer last ran.
  private static var replacedImages: [AnyObject] = []

  /// The observer of the main run loop that hands the replaced images to `queue`, made with the first image.
  private static var observer: CFRunLoopObserver?

  /// The images that the main thread handed to `queue`, guarded by `lock`.
  private static var handedOffImages: [AnyObject] = []

  /// The lock that guards `handedOffImages`.
  private static let lock = UnfairLock()

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

    lock.withLock {
      handedOffImages.append(contentsOf: replacedImages)
    }
    // the array keeps its capacity, so that the next replaced images append without allocating
    replacedImages.removeAll(keepingCapacity: true)

    queue.async {
      // the images are taken out under the lock and released when this block's local goes away, instead of with the
      // block, which the main thread can release last
      var images: [AnyObject] = []
      lock.withLock {
        swap(&images, &handedOffImages)
      }
      withExtendedLifetime(images) {}
    }
  }

  // MARK: - Testing

  #if DEBUG
  enum Test {

    /// The number of replaced images that the main thread hasn't handed to the queue.
    static var replacedImageCount: Int {
      replacedImages.count
    }

    /// The number of replaced images that the main thread hands to the queue without waiting for the observer.
    static var replacedImageCountToHandOff: Int {
      Constants.replacedImageCountToHandOff
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

    /// The number of replaced images at which the main thread hands them to the queue without waiting for the observer,
    /// more than a frame of scrolling replaces, which bounds the images that a host that doesn't turn the run loop keeps.
    static let replacedImageCountToHandOff = 64

    /// The order of the observer, after Core Animation's commit observer, which has order 2,000,000, and commits the
    /// main thread's transaction before the run loop waits and when it exits, as the observer runs.
    static let observerOrder: CFIndex = 2000001
  }
}

#endif
