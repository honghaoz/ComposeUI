//
//  TextLabelImageCacheTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/17/26.
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

class TextLabelImageCacheTests: XCTestCase {

  override func tearDown() {
    // a test that pauses the workers leaves them running for the next one
    TextLabelImageCache.Test.resumeDrawings()
    super.tearDown()
  }

  // MARK: - Drawing

  func test_prefetch_drawsTheImageOnAWorker() throws {
    // given: a cache with room for a label's image
    let cache = Self.makeCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))

    // when: prefetching the label, and waiting for the workers
    cache.prefetch(key)
    TextLabelImageCache.Test.waitForDrawings()

    // then: the label takes an image of its size's pixels, drawn on another thread, and the cache forgets the drawing
    let result = try unwrap(cache.takeResult(for: key))
    switch result {
    case .image(let image):
      expect(image?.width) == 200
      expect(image?.height) == 40
    case .drawnByAppKit:
      fail("the text draws in a layer")
    }
    expect(cache.test.entryCount) == 0
    expect(cache.test.bytes) == 0
    expect(cache.takeResult(for: key) == nil) == true
  }

  func test_prefetch_textThatAppKitDraws_findsItDrawnByAppKit() throws {
    // given: a cache, and a label with a style that a label leaves to AppKit's drawing
    let cache = Self.makeCache()
    let key = try Self.key(NSAttributedString(string: "Struck", attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]), size: CGSize(width: 100, height: 20))

    // when: prefetching the label
    cache.prefetch(key)
    TextLabelImageCache.Test.waitForDrawings()

    // then: the label finds that AppKit draws its text
    switch cache.takeResult(for: key) {
    case .drawnByAppKit:
      break
    case .image,
         .none:
      fail("a strikethrough draws through AppKit")
    }
  }

  func test_prefetch_sizeWithoutPixels_findsAnImageWithoutPixels() throws {
    // given: a cache, and a label without pixels
    let cache = Self.makeCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 0, height: 20))

    // when: prefetching the label
    cache.prefetch(key)
    TextLabelImageCache.Test.waitForDrawings()

    // then: the label finds that its text draws in a layer, without pixels to draw
    switch cache.takeResult(for: key) {
    case .image(let image):
      expect(image) == nil
    case .drawnByAppKit,
         .none:
      fail("the text draws in a layer")
    }
  }

  func test_prefetch_sameKeyTwice_drawsOnce() throws {
    // given: a cache, with its workers paused
    let cache = Self.makeCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))
    TextLabelImageCache.Test.finishDrawingsAndPause()
    let finishedCount = TextLabelImageCache.Test.finishedDrawingCount

    // when: prefetching the label twice, and letting the workers draw
    cache.prefetch(key)
    cache.prefetch(TextLabelImageCache.Key(text: key.text, size: key.size, numberOfLines: key.numberOfLines, lineBreakMode: key.lineBreakMode, inset: key.inset, environment: key.environment))
    TextLabelImageCache.Test.waitForDrawings()

    // then: one drawing is made
    expect(cache.test.entryCount) == 1
    expect(TextLabelImageCache.Test.finishedDrawingCount) == finishedCount + 1
  }

  func test_takeResult_beforeTheDrawingFinishes_cancelsIt() throws {
    // given: a cache that requested a drawing, with its workers paused
    let cache = Self.makeCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))
    TextLabelImageCache.Test.finishDrawingsAndPause()
    let finishedCount = TextLabelImageCache.Test.finishedDrawingCount
    cache.prefetch(key)
    expect(cache.test.isPending(key)) == true

    // when: the label takes the result before a worker draws it
    let result = cache.takeResult(for: key)

    // then: there's no result, and the worker skips the drawing, since the label draws its text itself
    expect(result == nil) == true
    TextLabelImageCache.Test.waitForDrawings()
    expect(TextLabelImageCache.Test.finishedDrawingCount) == finishedCount
    expect(cache.test.isPending(key)) == nil
  }

  // MARK: - Eviction

  func test_prefetch_overMaximumBytes_evictsTheFirstRequests() throws {
    // given: a cache with room for two images, with its workers paused
    let cache = TextLabelImageCache()
    let first = try Self.key("First", size: CGSize(width: 100, height: 20))
    let second = try Self.key("Second", size: CGSize(width: 100, height: 20))
    let third = try Self.key("Third", size: CGSize(width: 100, height: 20))
    let imageBytes = 200 * 40 * 4
    cache.maximumBytes = imageBytes * 2
    TextLabelImageCache.Test.finishDrawingsAndPause()
    let finishedCount = TextLabelImageCache.Test.finishedDrawingCount

    // when: prefetching three labels
    cache.prefetch(first)
    cache.prefetch(second)
    cache.prefetch(third)

    // then: the first request is evicted, and its drawing is skipped
    expect(cache.test.isPending(first)) == nil
    expect(cache.test.isPending(second)) == true
    expect(cache.test.isPending(third)) == true
    expect(cache.test.bytes) == imageBytes * 2
    TextLabelImageCache.Test.waitForDrawings()
    expect(TextLabelImageCache.Test.finishedDrawingCount) == finishedCount + 2

    // when: lowering the room to one image
    cache.maximumBytes = imageBytes

    // then: the second request is evicted too
    expect(cache.test.isPending(second)) == nil
    expect(cache.test.isPending(third)) == false
    expect(cache.test.bytes) == imageBytes
  }

  func test_prefetch_imageLargerThanMaximumBytes_isntDrawn() throws {
    // given: a cache with room for less than an image
    let cache = TextLabelImageCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))
    cache.maximumBytes = 200 * 40 * 4 - 1

    // when: prefetching the label
    cache.prefetch(key)

    // then: the label isn't drawn
    expect(cache.test.entryCount) == 0
    expect(cache.test.bytes) == 0
  }

  // MARK: - Invalidation

  func test_removeAll_forgetsAndCancelsTheDrawings() throws {
    // given: a cache that requested a drawing, with its workers paused
    let cache = Self.makeCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))
    TextLabelImageCache.Test.finishDrawingsAndPause()
    let finishedCount = TextLabelImageCache.Test.finishedDrawingCount
    cache.prefetch(key)

    // when: removing all the drawings
    cache.removeAll()

    // then: the cache forgets the drawing, and the worker skips it
    expect(cache.test.entryCount) == 0
    expect(cache.test.bytes) == 0
    TextLabelImageCache.Test.waitForDrawings()
    expect(TextLabelImageCache.Test.finishedDrawingCount) == finishedCount
  }

  func test_deinit_cancelsTheDrawings() throws {
    // given: a cache that requested a drawing, with its workers paused
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))
    TextLabelImageCache.Test.finishDrawingsAndPause()
    let finishedCount = TextLabelImageCache.Test.finishedDrawingCount
    weak var weakCache: TextLabelImageCache?
    autoreleasepool {
      let cache = Self.makeCache()
      cache.prefetch(key)
      weakCache = cache
    }

    // then: the cache goes away, and the worker skips its drawing
    expect(weakCache) == nil
    TextLabelImageCache.Test.waitForDrawings()
    expect(TextLabelImageCache.Test.finishedDrawingCount) == finishedCount
  }

  func test_memoryWarning_emptiesEveryCache() throws {
    // given: two caches with drawings, with the workers paused
    let firstCache = Self.makeCache()
    let secondCache = Self.makeCache()
    TextLabelImageCache.Test.finishDrawingsAndPause()
    try firstCache.prefetch(Self.key("First", size: CGSize(width: 100, height: 20)))
    try secondCache.prefetch(Self.key("Second", size: CGSize(width: 100, height: 20)))

    // when: the system is low on memory
    MemoryWarning.handleMemoryWarning()

    // then: both caches are empty
    expect(firstCache.test.entryCount) == 0
    expect(secondCache.test.entryCount) == 0
  }

  func test_systemColorsChange_emptiesEveryCache() throws {
    // given: two caches with drawings, with the workers paused
    let firstCache = Self.makeCache()
    let secondCache = Self.makeCache()
    TextLabelImageCache.Test.finishDrawingsAndPause()
    try firstCache.prefetch(Self.key("First", size: CGSize(width: 100, height: 20)))
    try secondCache.prefetch(Self.key("Second", size: CGSize(width: 100, height: 20)))

    // when: the system colors change, which a key doesn't include
    NotificationCenter.default.post(name: NSColor.systemColorsDidChangeNotification, object: nil)

    // then: both caches are empty
    expect(firstCache.test.entryCount) == 0
    expect(secondCache.test.entryCount) == 0
  }

  // MARK: - Drawing

  func test_drawing_finishedAfterCancel_staysCancelled() {
    // given: a drawing that the cache cancelled while a worker drew it
    let drawing = TextLabelImageCache.Drawing()
    drawing.cancel()

    // when: the worker finishes it
    drawing.finish(.drawnByAppKit)

    // then: the drawing stays cancelled, without a result that no one takes
    expect(drawing.isPending) == false
    expect(drawing.takeResultOrCancel() == nil) == true
  }

  // MARK: - Key

  func test_key_mutableText_keepsACopy() throws {
    // given: a key of a mutable text
    let text = NSMutableAttributedString(string: "Hello")
    let key = try Self.key(text, size: CGSize(width: 100, height: 20))

    // when: the text changes
    text.mutableString.append(", world")

    // then: the key keeps the text as it was
    expect(key.text.string) == "Hello"
    expect(key.text is NSMutableAttributedString) == false
  }

  func test_key_equality() throws {
    // given: a key
    let text = NSAttributedString(string: "Hello")
    let environment = try Self.environment()
    let key = TextLabelImageCache.Key(text: text, size: CGSize(width: 100, height: 20), numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment)

    // then: a key of the same text object, or of an equal text, is equal, with the same hash
    let sameText = TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment)
    let equalText = TextLabelImageCache.Key(text: NSAttributedString(string: "Hello"), size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment)
    expect(sameText) == key
    expect(equalText) == key
    expect(equalText.hashValue) == key.hashValue

    // then: a key with any other input isn't equal
    let darkAppearance = try unwrap(NSAppearance(named: .darkAqua))
    let displayP3 = try unwrap(CGColorSpace(name: CGColorSpace.displayP3))
    let otherKeys = [
      TextLabelImageCache.Key(text: NSAttributedString(string: "Hi"), size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: text, size: CGSize(width: 100, height: 21), numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 2, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byWordWrapping, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: CGSize(width: 1, height: 0), environment: environment),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: TextLabelImageCache.Environment(scale: 1, colorSpace: environment.colorSpace, appearance: environment.appearance)),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: TextLabelImageCache.Environment(scale: 2, colorSpace: displayP3, appearance: environment.appearance)),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: TextLabelImageCache.Environment(scale: 2, colorSpace: environment.colorSpace, appearance: darkAppearance)),
    ]
    for otherKey in otherKeys {
      expect(otherKey) != key
    }
  }

  func test_environment_ofAWindow() throws {
    // given: a window at a scale of 2, in Display P3
    let renderer = try WindowRenderer(size: CGSize(width: 100, height: 20), scale: 2, colorSpace: .displayP3)
    let appearance = try unwrap(NSAppearance(named: .darkAqua))

    // when: getting the environment of a label in it
    let environment = try unwrap(TextLabelImageCache.Environment.of(window: renderer.window, appearance: appearance))

    // then: it has the window's scale and color space, and the label's appearance
    expect(environment.scale) == 2
    expect(environment.colorSpace) == NSColorSpace.displayP3.cgColorSpace
    expect(environment.appearance) === appearance
  }

  // MARK: - Helpers

  private static func makeCache() -> TextLabelImageCache {
    let cache = TextLabelImageCache()
    cache.maximumBytes = 10000000
    return cache
  }

  private static func environment() throws -> TextLabelImageCache.Environment {
    try TextLabelImageCache.Environment(scale: 2, colorSpace: unwrap(CGColorSpace(name: CGColorSpace.sRGB)), appearance: unwrap(NSAppearance(named: .aqua)))
  }

  private static func key(_ string: String, size: CGSize) throws -> TextLabelImageCache.Key {
    try key(NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.black]), size: size)
  }

  private static func key(_ text: NSAttributedString, size: CGSize) throws -> TextLabelImageCache.Key {
    try TextLabelImageCache.Key(text: text, size: size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment())
  }
}

#endif
