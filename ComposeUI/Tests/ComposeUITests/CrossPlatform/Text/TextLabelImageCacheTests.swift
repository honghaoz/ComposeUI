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

  func test_takeResult_labelsOfTheSameKey_eachTakeTheImage() throws {
    // given: a cache that drew the image of two labels of the same key
    let cache = Self.makeCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))
    let otherKey = Self.otherLabelsKey(of: key)
    cache.prefetch(key)
    cache.prefetch(otherKey)
    TextLabelImageCache.Test.waitForDrawings()

    // when: the first label takes the result
    let firstImage = try unwrap(Self.image(of: cache.takeResult(for: key)))

    // then: the cache keeps the drawing for the other label, with the bytes of its image counted once
    expect(cache.test.entryCount) == 1
    expect(cache.test.bytes) == 200 * 40 * 4

    // when: the other label takes the result
    let secondImage = try unwrap(Self.image(of: cache.takeResult(for: otherKey)))

    // then: the other label takes the same image, and the cache forgets the drawing
    expect(secondImage) === firstImage
    expect(cache.test.entryCount) == 0
    expect(cache.test.bytes) == 0
    expect(cache.takeResult(for: key) == nil) == true
  }

  func test_takeResult_beforeTheDrawingFinishes_leavesItToTheOtherLabelOfTheKey() throws {
    // given: a cache that requested the drawing of two labels of the same key, with its workers paused
    let cache = Self.makeCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))
    let otherKey = Self.otherLabelsKey(of: key)
    TextLabelImageCache.Test.finishDrawingsAndPause()
    let finishedCount = TextLabelImageCache.Test.finishedDrawingCount
    cache.prefetch(key)
    cache.prefetch(otherKey)

    // when: the first label takes the result twice before a worker draws it, as when it gets its text and when it
    // displays
    let firstResults = [cache.takeResult(for: key), cache.takeResult(for: key)]

    // then: there's no result, and the drawing stays for the other label
    expect(firstResults.map { $0 == nil }) == [true, true]
    expect(cache.test.isPending(key)) == true

    // when: a worker draws it, and the other label takes the result
    TextLabelImageCache.Test.waitForDrawings()
    let secondResult = cache.takeResult(for: otherKey)

    // then: the other label takes the image, and the drawing stays for the first label's request, which no take used
    expect(TextLabelImageCache.Test.finishedDrawingCount) == finishedCount + 1
    expect(Self.image(of: secondResult)?.width) == 200
    expect(cache.test.entryCount) == 1
  }

  func test_takeResult_bothLabelsOfTheKeyBeforeTheDrawingFinishes_leaveItForTheirNextTakes() throws {
    // given: a cache that requested the drawing of two labels of the same key, with its workers paused
    let cache = Self.makeCache()
    let key = try Self.key("Row 12 title", size: CGSize(width: 100, height: 20))
    let otherKey = Self.otherLabelsKey(of: key)
    TextLabelImageCache.Test.finishDrawingsAndPause()
    let finishedCount = TextLabelImageCache.Test.finishedDrawingCount
    cache.prefetch(key)
    cache.prefetch(otherKey)

    // when: both labels take the result before a worker draws it
    let firstResults = [cache.takeResult(for: key), cache.takeResult(for: otherKey)]

    // then: there's no result, and the drawing stays, since a label takes again when it displays
    expect(firstResults.map { $0 == nil }) == [true, true]
    expect(cache.test.isPending(key)) == true

    // when: a worker draws it, and both labels take the result again, as when they display
    TextLabelImageCache.Test.waitForDrawings()
    let images = [Self.image(of: cache.takeResult(for: key)), Self.image(of: cache.takeResult(for: otherKey))]

    // then: both labels take the image, and the cache forgets the drawing
    expect(TextLabelImageCache.Test.finishedDrawingCount) == finishedCount + 1
    expect(images.map { $0?.width }) == [200, 200]
    expect(cache.test.entryCount) == 0
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

  func test_prefetch_overMaximumBytes_skipsTheEntriesThatLabelsTook() throws {
    // given: a cache with room for two images, with its workers paused, that requested two labels, the first of which
    // a label took
    let cache = TextLabelImageCache()
    let first = try Self.key("First", size: CGSize(width: 100, height: 20))
    let second = try Self.key("Second", size: CGSize(width: 100, height: 20))
    let third = try Self.key("Third", size: CGSize(width: 100, height: 20))
    let fourth = try Self.key("Fourth", size: CGSize(width: 100, height: 20))
    let imageBytes = 200 * 40 * 4
    cache.maximumBytes = imageBytes * 2
    TextLabelImageCache.Test.finishDrawingsAndPause()
    cache.prefetch(first)
    cache.prefetch(second)
    _ = cache.takeResult(for: first)

    // when: prefetching two more labels
    cache.prefetch(third)
    cache.prefetch(fourth)

    // then: the second request, the oldest one left, is evicted, and the third request took the slot in the order that
    // the first label's take freed
    expect(cache.test.isPending(second)) == nil
    expect(cache.test.isPending(third)) == true
    expect(cache.test.isPending(fourth)) == true
    expect(cache.test.bytes) == imageBytes * 2
    expect(cache.test.evictionKeyCount) == 2
    expect(cache.test.evictionSlotCount) == 3
  }

  func test_prefetch_overMaximumBytes_evictsALabelRequestedAgainAfterTheEarlierRequests() throws {
    // given: a cache with room for two images, with its workers paused, that requested two labels, the first of which
    // a label took and requested again
    let cache = TextLabelImageCache()
    let first = try Self.key("First", size: CGSize(width: 100, height: 20))
    let second = try Self.key("Second", size: CGSize(width: 100, height: 20))
    let third = try Self.key("Third", size: CGSize(width: 100, height: 20))
    cache.maximumBytes = 200 * 40 * 4 * 2
    TextLabelImageCache.Test.finishDrawingsAndPause()
    cache.prefetch(first)
    cache.prefetch(second)
    _ = cache.takeResult(for: first)
    cache.prefetch(first)

    // when: prefetching a third label
    cache.prefetch(third)

    // then: the second request is evicted, since the first label's new request came after it
    expect(cache.test.isPending(second)) == nil
    expect(cache.test.isPending(first)) == true
    expect(cache.test.isPending(third)) == true
    expect(cache.test.evictionKeyCount) == 2
  }

  func test_prefetch_overMaximumBytesAfterRemoveAll_evictsTheFirstRequestAfterItInOneStep() throws {
    // given: a cache, with its workers paused, that removed all its drawings after requesting 100 labels, and then
    // requested two labels with room for two images
    let cache = TextLabelImageCache()
    let first = try Self.key("First", size: CGSize(width: 100, height: 20))
    let second = try Self.key("Second", size: CGSize(width: 100, height: 20))
    let third = try Self.key("Third", size: CGSize(width: 100, height: 20))
    let imageBytes = 200 * 40 * 4
    cache.maximumBytes = imageBytes * 100
    TextLabelImageCache.Test.finishDrawingsAndPause()
    for row in 0 ..< 100 {
      try cache.prefetch(Self.key("Row \(row)", size: CGSize(width: 100, height: 20)))
    }
    cache.removeAll()
    cache.maximumBytes = imageBytes * 2
    cache.prefetch(first)
    cache.prefetch(second)

    // when: prefetching a third label
    let counts = WorkCounter.counting {
      cache.prefetch(third)
    }

    // then: the first request after the removal is evicted, in one step, instead of one for each request before it,
    // and the order keeps only the slots of the requests after the removal
    expect(counts.imageEvictionSteps) == 1
    expect(cache.test.isPending(first)) == nil
    expect(cache.test.isPending(second)) == true
    expect(cache.test.isPending(third)) == true
    expect(cache.test.evictionKeyCount) == 2
    expect(cache.test.evictionSlotCount) == 3
  }

  func test_prefetch_overMaximumBytesAfterManyTakes_evictsInOneStep() throws {
    // given: a cache with room for two images, with its workers paused, whose labels took the drawings of 1,000 labels
    // before it requested two more
    let cache = TextLabelImageCache()
    let first = try Self.key("First", size: CGSize(width: 100, height: 20))
    let second = try Self.key("Second", size: CGSize(width: 100, height: 20))
    let third = try Self.key("Third", size: CGSize(width: 100, height: 20))
    cache.maximumBytes = 200 * 40 * 4 * 2
    TextLabelImageCache.Test.finishDrawingsAndPause()
    for row in 0 ..< 1000 {
      let key = try Self.key("Row \(row)", size: CGSize(width: 100, height: 20))
      cache.prefetch(key)
      _ = cache.takeResult(for: key)
    }
    cache.prefetch(first)
    cache.prefetch(second)

    // when: prefetching a third label
    let counts = WorkCounter.counting {
      cache.prefetch(third)
    }

    // then: the first of the two is evicted, in one step, instead of one for each label that took its drawing before,
    // and the 1,000 requests shared the slot that each take freed, instead of one slot each
    expect(counts.imageEvictionSteps) == 1
    expect(cache.test.isPending(first)) == nil
    expect(cache.test.isPending(second)) == true
    expect(cache.test.isPending(third)) == true
    expect(cache.test.evictionKeyCount) == 2
    expect(cache.test.evictionSlotCount) == 3
  }

  func test_maximumBytesLowered_afterALabelTookADrawingBetweenTwoOthers_evictsInRequestOrder() throws {
    // given: a cache with room for four images, with its workers paused, that requested four labels, the second of which
    // a label took
    let cache = TextLabelImageCache()
    let keys = try ["First", "Second", "Third", "Fourth"].map { try Self.key($0, size: CGSize(width: 100, height: 20)) }
    let imageBytes = 200 * 40 * 4
    cache.maximumBytes = imageBytes * 4
    TextLabelImageCache.Test.finishDrawingsAndPause()
    for key in keys {
      cache.prefetch(key)
    }
    _ = cache.takeResult(for: keys[1])

    // when: lowering the room to one image
    cache.maximumBytes = imageBytes

    // then: the first and the third requests are evicted
    expect(cache.test.isPending(keys[0])) == nil
    expect(cache.test.isPending(keys[2])) == nil
    expect(cache.test.isPending(keys[3])) == true

    // when: lowering the room to none
    cache.maximumBytes = 0

    // then: the last request is evicted too, and no entry is left in the order
    expect(cache.test.isPending(keys[3])) == nil
    expect(cache.test.entryCount) == 0
    expect(cache.test.evictionKeyCount) == 0
  }

  func test_maximumBytesLowered_afterALabelTookTheNewestDrawing_evictsInRequestOrder() throws {
    // given: a cache with room for three images, with its workers paused, that requested three labels, the last of which
    // a label took, and then requested a fourth
    let cache = TextLabelImageCache()
    let keys = try ["First", "Second", "Third", "Fourth"].map { try Self.key($0, size: CGSize(width: 100, height: 20)) }
    let imageBytes = 200 * 40 * 4
    cache.maximumBytes = imageBytes * 3
    TextLabelImageCache.Test.finishDrawingsAndPause()
    for key in keys.prefix(3) {
      cache.prefetch(key)
    }
    _ = cache.takeResult(for: keys[2])
    cache.prefetch(keys[3])

    // when: lowering the room to one image
    cache.maximumBytes = imageBytes

    // then: the first and the second requests are evicted, and the fourth, which came after them, is left
    expect(cache.test.isPending(keys[0])) == nil
    expect(cache.test.isPending(keys[1])) == nil
    expect(cache.test.isPending(keys[3])) == true
    expect(cache.test.evictionKeyCount) == 1

    // when: lowering the room to none
    cache.maximumBytes = 0

    // then: the fourth request is evicted too, and no entry is left in the order
    expect(cache.test.isPending(keys[3])) == nil
    expect(cache.test.evictionKeyCount) == 0
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

    // then: the cache forgets the drawing and its slot in the order, and the worker skips it
    expect(cache.test.entryCount) == 0
    expect(cache.test.evictionKeyCount) == 0
    expect(cache.test.evictionSlotCount) == 0
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

    // when: the system colors change
    NotificationCenter.default.post(name: NSColor.systemColorsDidChangeNotification, object: nil)

    // then: both caches are empty
    expect(firstCache.test.entryCount) == 0
    expect(secondCache.test.entryCount) == 0
  }

  func test_systemColorsChange_givesTheLabelsOtherKeys() throws {
    // given: a cache, and the key of a label in a window
    let cache = Self.makeCache()
    let renderer = try WindowRenderer(size: CGSize(width: 100, height: 20))
    let appearance = try unwrap(NSAppearance(named: .aqua))
    let text = NSAttributedString(string: "Hello")
    let makeKey = {
      try TextLabelImageCache.Key(text: text, size: CGSize(width: 100, height: 20), numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: unwrap(TextLabelImageCache.Environment.of(window: renderer.window, appearance: appearance)))
    }
    let key = try makeKey()

    // when: the system colors change, which the text's dynamic colors resolve to without a change of the appearance
    NotificationCenter.default.post(name: NSColor.systemColorsDidChangeNotification, object: nil)

    // then: the label's key differs, so that an image drawn before the change, even one that a label took, doesn't
    // match the label after it
    expect(try makeKey()) != key
    withExtendedLifetime(cache) {}
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

  func test_drawing_result_isTheResultOnceFinished() {
    // given: a pending drawing, and a cancelled one
    let drawing = TextLabelImageCache.Drawing()
    let cancelledDrawing = TextLabelImageCache.Drawing()
    cancelledDrawing.cancel()

    // then: neither has a result
    expect(drawing.result == nil) == true
    expect(cancelledDrawing.result == nil) == true

    // when: a worker finishes the drawing
    drawing.finish(.drawnByAppKit)

    // then: the drawing has the result, and reading it leaves it for the next label
    switch drawing.result {
    case .drawnByAppKit:
      break
    case .image,
         .none:
      fail("the drawing found that AppKit draws the text")
    }
    expect(drawing.takeResultOrCancel() == nil) == false
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

    // then: a key with any other input isn't equal, including a text of the same string with other attributes, which has
    // the same hash
    let darkAppearance = try unwrap(NSAppearance(named: .darkAqua))
    let displayP3 = try unwrap(CGColorSpace(name: CGColorSpace.displayP3))
    let otherAttributes = NSAttributedString(string: "Hello", attributes: [.foregroundColor: NSColor.red])
    expect(otherAttributes.hash) == text.hash
    let otherKeys = [
      TextLabelImageCache.Key(text: NSAttributedString(string: "Hi"), size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: otherAttributes, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: text, size: CGSize(width: 100, height: 21), numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 2, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byWordWrapping, inset: .zero, environment: environment),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: CGSize(width: 1, height: 0), environment: environment),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: TextLabelImageCache.Environment(scale: 1, colorSpace: environment.colorSpace, appearance: environment.appearance, systemColorsGeneration: 0)),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: TextLabelImageCache.Environment(scale: 2, colorSpace: displayP3, appearance: environment.appearance, systemColorsGeneration: 0)),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: TextLabelImageCache.Environment(scale: 2, colorSpace: environment.colorSpace, appearance: darkAppearance, systemColorsGeneration: 0)),
      TextLabelImageCache.Key(text: text, size: key.size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: TextLabelImageCache.Environment(scale: 2, colorSpace: environment.colorSpace, appearance: environment.appearance, systemColorsGeneration: 1)),
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
    try TextLabelImageCache.Environment(scale: 2, colorSpace: unwrap(CGColorSpace(name: CGColorSpace.sRGB)), appearance: unwrap(NSAppearance(named: .aqua)), systemColorsGeneration: 0)
  }

  private static func key(_ string: String, size: CGSize) throws -> TextLabelImageCache.Key {
    try key(NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.black]), size: size)
  }

  private static func key(_ text: NSAttributedString, size: CGSize) throws -> TextLabelImageCache.Key {
    try TextLabelImageCache.Key(text: text, size: size, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero, environment: environment())
  }

  /// Returns the key of another label with an equal text and the same settings, size and window as a key's label.
  private static func otherLabelsKey(of key: TextLabelImageCache.Key) -> TextLabelImageCache.Key {
    TextLabelImageCache.Key(
      text: NSAttributedString(attributedString: key.text),
      size: key.size,
      numberOfLines: key.numberOfLines,
      lineBreakMode: key.lineBreakMode,
      inset: key.inset,
      environment: key.environment
    )
  }

  /// Returns the image of a result, `nil` for a result without an image, or no result.
  private static func image(of result: TextLabelImageCache.Result?) -> CGImage? {
    switch result {
    case .image(let image):
      return image
    case .drawnByAppKit,
         .none:
      return nil
    }
  }
}

#endif
