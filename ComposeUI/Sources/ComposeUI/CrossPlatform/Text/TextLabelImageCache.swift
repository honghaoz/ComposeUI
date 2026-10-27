//
//  TextLabelImageCache.swift
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

import AppKit

/// The images of a compose view's labels, drawn ahead of time on background threads, for the labels about to scroll in.
///
/// A compose view keeps a cache among its prefetch caches. A text node's label item asks the cache to draw its text
/// when the item enters the view's prefetch region, and a label takes the result for its text, settings, size and
/// window when it gets its text, or when it displays without an image for them. A label without a result draws its text
/// itself, in the same pixels, so the cache only decides how much of the drawing is done ahead of time, never what a
/// label shows.
///
/// It's used on the main thread, while its workers draw on their own threads.
final class TextLabelImageCache {

  /// Whether labels draw ahead of time on the running system.
  ///
  /// An image matches the pixels of a label's drawing layer, which a label draws in only on the systems that the label
  /// drawing parity tests verify.
  static var isSupported: Bool {
    #if DEBUG
    if isTurnedOff {
      return false
    }
    #endif
    return TextLabelView.isLayerDrawingVerified
  }

  #if DEBUG
  /// Whether tests turn drawing ahead of time off, to check what a system that doesn't support it does.
  private static var isTurnedOff = false
  #endif

  // MARK: - Key

  /// The window, the appearance and the system colors that a label shows in, which its image is drawn for.
  struct Environment {

    /// The scale of the window's backing store.
    let scale: CGFloat

    /// The window's color space, which Core Animation draws the label's drawing layer in.
    let colorSpace: CGColorSpace

    /// The label's appearance, which resolves the text's dynamic colors.
    let appearance: NSAppearance

    /// The generation of the system colors, which the text's dynamic colors resolve to, and which change without a
    /// change of the appearance.
    let systemColorsGeneration: Int

    /// Returns the environment of a label.
    ///
    /// - Parameters:
    ///   - window: The window that the label shows in.
    ///   - appearance: The label's appearance.
    /// - Returns: The environment, `nil` for a window without a color space, since the color space that Core Animation
    ///   draws the label's drawing layer in isn't known then.
    static func of(window: NSWindow, appearance: NSAppearance) -> Environment? {
      window.colorSpace?.cgColorSpace.map {
        Environment(scale: window.backingScaleFactor, colorSpace: $0, appearance: appearance, systemColorsGeneration: TextLabelImageCache.systemColorsGeneration)
      }
    }
  }

  /// What a label's image depends on: the text, its settings, the label's size, and the window that it shows in.
  struct Key: Hashable {

    /// The text as the label is set to show it, which doesn't change, since a worker reads it.
    let text: NSAttributedString

    /// The label's size.
    let size: CGSize

    /// The maximum number of lines that the text lays out in, 0 for no limit.
    let numberOfLines: Int

    /// The line break mode of the text's last line.
    let lineBreakMode: NSLineBreakMode

    /// The label's text container inset.
    let inset: CGSize

    /// The window and the appearance that the label shows in.
    let environment: Environment

    /// Makes the key of a label's image.
    ///
    /// - Parameters:
    ///   - text: The text as the label is set to show it.
    ///   - size: The label's size.
    ///   - numberOfLines: The maximum number of lines that the text lays out in, 0 for no limit.
    ///   - lineBreakMode: The line break mode of the text's last line.
    ///   - inset: The label's text container inset.
    ///   - environment: The window and the appearance that the label shows in.
    init(text: NSAttributedString, size: CGSize, numberOfLines: Int, lineBreakMode: NSLineBreakMode, inset: CGSize, environment: Environment) {
      // a mutable text can change after it's set, while a worker reads it, so the key keeps a copy
      self.text = text is NSMutableAttributedString ? NSAttributedString(attributedString: text) : text
      self.size = size
      self.numberOfLines = numberOfLines
      self.lineBreakMode = lineBreakMode
      self.inset = inset
      self.environment = environment
    }

    static func == (lhs: Key, rhs: Key) -> Bool {
      // a text node passes the same text object across render passes, so identity settles most comparisons without
      // comparing the texts' contents
      (lhs.text === rhs.text || lhs.text.isEqual(to: rhs.text)) &&
        lhs.size == rhs.size &&
        lhs.numberOfLines == rhs.numberOfLines &&
        lhs.lineBreakMode == rhs.lineBreakMode &&
        lhs.inset == rhs.inset &&
        lhs.environment.scale == rhs.environment.scale &&
        lhs.environment.colorSpace == rhs.environment.colorSpace &&
        lhs.environment.appearance.name == rhs.environment.appearance.name &&
        lhs.environment.systemColorsGeneration == rhs.environment.systemColorsGeneration
    }

    func hash(into hasher: inout Hasher) {
      // the labels of one view share the window and usually the inset, so the hash leaves them to the comparison
      hasher.combine(text.hash)
      hasher.combine(size.width)
      hasher.combine(size.height)
      hasher.combine(numberOfLines)
      hasher.combine(lineBreakMode)
    }
  }

  // MARK: - Result

  /// What a drawing ahead of time found for a label's text.
  enum Result {

    /// The text draws the same pixels in the label's drawing layer as in the image, `nil` for a size without pixels.
    case image(CGImage?)

    /// The text has a style that a label leaves to AppKit's drawing, see `NSAttributedString.drawsTheSameInALayer`.
    case drawnByAppKit
  }

  // MARK: - Caching

  /// The bytes that the entries' images take at most, which a label's request sets from the region that the compose view
  /// prefetches.
  ///
  /// A request that goes over it evicts the entries requested first, as does lowering it.
  var maximumBytes = 0 {
    didSet {
      if maximumBytes < oldValue {
        evictIfNeeded()
      }
    }
  }

  /// The drawings that labels haven't taken yet, by their keys.
  private var entries: [Key: Entry] = [:]

  /// The entries' keys in the order of their requests, which eviction follows.
  private var order = RequestOrder()

  /// The bytes that the entries' images take at most.
  private var bytes = 0

  init() {
    Self.startObservingIfNeeded()
    Self.caches.add(self)
  }

  deinit {
    removeAll()
  }

  /// Draws a label ahead of time, unless it's drawn or being drawn.
  ///
  /// The labels of a key share its drawing, which each of them takes, see `takeResult(for:)`. An image that takes more
  /// than `maximumBytes` isn't drawn.
  ///
  /// - Parameter key: The key of the label's image.
  func prefetch(_ key: Key) {
    if let index = entries.index(forKey: key) {
      entries.values[index].requestCount += 1
    } else {
      let entryBytes = Self.bytes(of: key)
      guard entryBytes <= maximumBytes else {
        return
      }

      let drawing = Drawing()
      entries[key] = Entry(drawing: drawing, bytes: entryBytes, sequence: order.append(key), requestCount: 1)
      bytes += entryBytes
      evictIfNeeded()
      Self.workers.next().draw(key, into: drawing)
    }
  }

  /// Returns the result of a label's drawing ahead of time, and forgets the drawing once every label that it was
  /// requested for took it, since a label keeps its image.
  ///
  /// A label that finds the drawing unfinished takes no share of it, since a label takes again when it displays, and
  /// leaves it to the labels of its key, unless it's the drawing's last request, which cancels it, since no other label
  /// is left to take it.
  ///
  /// - Parameter key: The key of the label's image.
  /// - Returns: The result, `nil` if the drawing isn't finished, or there's none.
  func takeResult(for key: Key) -> Result? {
    guard let index = entries.index(forKey: key) else {
      return nil
    }

    if entries.values[index].requestCount > 1 {
      guard let result = entries.values[index].drawing.result else {
        return nil
      }
      entries.values[index].requestCount -= 1
      return result
    } else {
      let entry = entries.remove(at: index).value
      order.remove(entry.sequence)
      bytes -= entry.bytes
      return entry.drawing.takeResultOrCancel()
    }
  }

  /// Forgets every drawing, and cancels the ones that aren't finished.
  func removeAll() {
    for entry in entries.values {
      entry.drawing.cancel()
    }
    entries.removeAll()
    order.removeAll()
    bytes = 0
  }

  /// Evicts the entries requested first, until the entries' images fit `maximumBytes`.
  private func evictIfNeeded() {
    while bytes > maximumBytes, let sequence = order.oldest, let key = order.remove(sequence) {
      #if DEBUG
      WorkCounter.count(.imageEvictionStep)
      #endif
      if let entry = entries.removeValue(forKey: key) {
        bytes -= entry.bytes
        entry.drawing.cancel()
      }
    }
  }

  /// Returns the bytes of the images that fill a size, 4 for each pixel.
  ///
  /// - Parameters:
  ///   - size: The size that the images fill.
  ///   - scale: The scale of the window's backing store.
  /// - Returns: The bytes.
  static func bytes(of size: CGSize, scale: CGFloat) -> Int {
    Int((size.width * scale).rounded(.up)) * Int((size.height * scale).rounded(.up)) * 4
  }

  /// Returns the bytes that a label's image takes at most.
  private static func bytes(of key: Key) -> Int {
    bytes(of: key.size, scale: key.environment.scale)
  }

  /// A drawing that a label hasn't taken yet.
  private struct Entry {

    /// The drawing.
    let drawing: Drawing

    /// The bytes that the drawing's image takes at most.
    let bytes: Int

    /// The entry's sequence number in the order of the requests.
    let sequence: Int

    /// The number of labels about to scroll in that the drawing was requested for, and that haven't taken it.
    var requestCount: Int
  }

  /// The keys of the entries in the order of their requests, linked by their sequence numbers, so that eviction takes
  /// the oldest without searching the entries or going past the ones that labels took.
  ///
  /// A link is read and written back, instead of changed in place through `links[sequence]?.newer`, which allocates,
  /// and the keys are kept apart from the links, so that writing a link back doesn't copy a key.
  private struct RequestOrder {

    /// The keys by their sequence numbers.
    private(set) var keys: [Int: Key] = [:]

    /// The links by their sequence numbers.
    private(set) var links: [Int: Link] = [:]

    /// The sequence number of the oldest key, `nil` if there's none.
    private(set) var oldest: Int?

    /// The sequence number of the newest key, `nil` if there's none.
    private var newest: Int?

    /// The sequence number of the next key.
    private var next = 0

    /// Adds a key as the newest.
    ///
    /// - Parameter key: The key.
    /// - Returns: The key's sequence number.
    mutating func append(_ key: Key) -> Int {
      let sequence = next
      next += 1
      keys[sequence] = key
      links[sequence] = Link(older: newest, newer: nil)
      if let newest {
        if var newestLink = links[newest] {
          newestLink.newer = sequence
          links[newest] = newestLink
        }
      } else {
        oldest = sequence
      }
      newest = sequence
      return sequence
    }

    /// Removes a key.
    ///
    /// - Parameter sequence: The key's sequence number.
    /// - Returns: The key, `nil` if there's none with the sequence number.
    @discardableResult
    mutating func remove(_ sequence: Int) -> Key? {
      if let link = links.removeValue(forKey: sequence) {
        unlink(link)
      }
      return keys.removeValue(forKey: sequence)
    }

    /// Removes every key.
    mutating func removeAll() {
      keys.removeAll()
      links.removeAll()
      oldest = nil
      newest = nil
    }

    /// Joins the keys before and after a key that left the order.
    ///
    /// - Parameter link: The link of the key that left.
    private mutating func unlink(_ link: Link) {
      if let older = link.older {
        if var olderLink = links[older] {
          olderLink.newer = link.newer
          links[older] = olderLink
        }
      } else {
        oldest = link.newer
      }
      if let newer = link.newer {
        if var newerLink = links[newer] {
          newerLink.older = link.older
          links[newer] = newerLink
        }
      } else {
        newest = link.older
      }
    }

    /// A key's place in the order.
    struct Link {

      /// The sequence number of the key before it, `nil` for the oldest.
      var older: Int?

      /// The sequence number of the key after it, `nil` for the newest.
      var newer: Int?
    }
  }

  // MARK: - Invalidation

  /// The caches of the compose views, which a memory warning, or a change of the system colors, empties.
  private static let caches = NSHashTable<TextLabelImageCache>.weakObjects()

  /// Whether the caches are emptied on a memory warning and on a change of the system colors.
  private static var isObserving = false

  /// The number of times that the system colors changed, which a key includes, so that an image drawn before a change,
  /// including one that a label took, doesn't match a label after it. Main thread only.
  private static var systemColorsGeneration = 0

  /// Starts emptying the caches on a memory warning, and on a change of the system colors, with one observer of each
  /// for every cache.
  private static func startObservingIfNeeded() {
    guard !isObserving else {
      return
    }
    isObserving = true

    MemoryWarning.addHandler {
      removeAllInEveryCache()
    }
    NotificationCenter.default.addObserver(forName: NSColor.systemColorsDidChangeNotification, object: nil, queue: .main) { _ in
      systemColorsGeneration += 1
      removeAllInEveryCache()
    }
  }

  /// Empties every cache.
  private static func removeAllInEveryCache() {
    for cache in caches.allObjects {
      cache.removeAll()
    }
  }

  // MARK: - Drawing

  /// A label's drawing ahead of time, which the cache requests on the main thread and a worker finishes on its own.
  ///
  /// Its state is the only state that the two threads share, under a lock that's held only to read or change it.
  final class Drawing {

    private enum State {

      /// A worker hasn't finished the drawing.
      case pending

      /// The cache forgot the drawing before a worker finished it.
      case cancelled

      /// A worker finished the drawing.
      case finished(Result)
    }

    /// The lock that guards every drawing's state.
    private static let lock = UnfairLock()

    private var state = State.pending

    /// Whether a worker should still draw it, which it checks before drawing.
    var isPending: Bool {
      Self.lock.withLock {
        switch state {
        case .pending:
          return true
        case .cancelled,
             .finished:
          return false
        }
      }
    }

    /// The result, `nil` if the drawing isn't finished.
    var result: Result? {
      Self.lock.withLock {
        switch state {
        case .pending,
             .cancelled:
          return nil
        case .finished(let result):
          return result
        }
      }
    }

    /// Finishes the drawing with a result, unless it's cancelled.
    func finish(_ result: Result) {
      Self.lock.withLock {
        switch state {
        case .pending:
          state = .finished(result)
          #if DEBUG
          Self.finishedCount += 1
          #endif
        case .cancelled,
             .finished:
          break
        }
      }
    }

    #if DEBUG
    /// The number of drawings that workers finished, guarded by the lock.
    private static var finishedCount = 0

    /// The number of drawings that workers finished, which tests read to check that a worker skips a cancelled one.
    static var finishedDrawingCount: Int {
      lock.withLock {
        finishedCount
      }
    }
    #endif

    /// Cancels the drawing, unless it's finished.
    func cancel() {
      Self.lock.withLock {
        switch state {
        case .pending:
          state = .cancelled
        case .cancelled,
             .finished:
          break
        }
      }
    }

    /// Returns the result, or cancels the drawing if it isn't finished, in one step, so that a worker that finishes in
    /// between doesn't leave a result that no one takes.
    func takeResultOrCancel() -> Result? {
      Self.lock.withLock {
        switch state {
        case .pending:
          state = .cancelled
          return nil
        case .cancelled:
          return nil
        case .finished(let result):
          return result
        }
      }
    }
  }

  // MARK: - Workers

  /// The workers of every cache.
  ///
  /// Two keep the labels of a fast scroll drawn in time, which one didn't, when each scroll step followed the previous
  /// one without a pause.
  private static let workers = Workers(count: 2)

  /// Workers that take turns drawing.
  private final class Workers {

    private let workers: [Worker]

    /// The index of the worker that draws next. Main thread only.
    private var nextIndex = 0

    init(count: Int) {
      workers = (0 ..< count).map(Worker.init(index:))
    }

    /// Returns the worker that draws next.
    func next() -> Worker {
      let worker = workers[nextIndex]
      nextIndex = (nextIndex + 1) % workers.count
      return worker
    }

    #if DEBUG
    /// Whether the workers' queues are suspended.
    private var isPaused = false

    /// Waits until the workers finish their drawings, resuming them first if they're paused.
    func waitUntilIdle() {
      resume()
      // a block runs on a serial queue after the blocks before it
      for worker in workers {
        worker.queue.sync {}
      }
    }

    /// Waits until the workers finish their drawings, and pauses them, so that the drawings requested from then on wait
    /// for `resume()`.
    func finishAndPause() {
      waitUntilIdle()
      for worker in workers {
        worker.queue.suspend()
      }
      isPaused = true
    }

    /// Resumes the workers' queues, if they're paused.
    func resume() {
      guard isPaused else {
        return
      }
      for worker in workers {
        worker.queue.resume()
      }
      isPaused = false
    }
    #endif
  }

  /// A worker that draws labels on a serial queue of its own, with a drawer that only the queue uses.
  private final class Worker {

    let queue: DispatchQueue

    /// The drawer, which only `queue` uses, as TextKit requires.
    private let drawer = TextLabelDrawer()

    init(index: Int) {
      // each drawing gets an autorelease pool, so that the objects that drawing a text autoreleases go away with it
      queue = DispatchQueue(label: "com.honghaoz.ComposeUI.TextLabelImageCache.worker\(index)", qos: .userInitiated, autoreleaseFrequency: .workItem)
    }

    /// Draws a label's image on the worker's queue.
    func draw(_ key: Key, into drawing: Drawing) {
      queue.async { [drawer] in
        // the cache cancels a drawing that it no longer needs, which the worker then skips
        guard drawing.isPending else {
          return
        }
        drawing.finish(Self.result(of: key, drawer: drawer))
      }
    }

    /// Draws a label's image with a drawer, as the label's drawing layer would draw its text.
    private static func result(of key: Key, drawer: TextLabelDrawer) -> Result {
      // the styles are checked on the text as the storage shows it, with the fonts that the storage substitutes for the
      // characters that their fonts lack, as a label checks them
      drawer.textStorage.setAttributedString(TextLabelDrawer.shownText(of: key.text))
      guard drawer.textStorage.drawsTheSameInALayer else {
        return .drawnByAppKit
      }

      let environment = key.environment
      drawer.scaleShadows(by: environment.scale)
      drawer.numberOfLines = key.numberOfLines
      drawer.lineBreakMode = key.lineBreakMode
      return .image(
        drawer.makeImage(
          size: key.size,
          inset: key.inset,
          scale: environment.scale,
          colorSpace: environment.colorSpace,
          appearance: environment.appearance
        )
      )
    }
  }

  // MARK: - Testing

  #if DEBUG

  var test: Test { Test(host: self) }

  class Test {

    private let host: TextLabelImageCache

    fileprivate init(host: TextLabelImageCache) {
      ComposeUI.assert(Thread.isRunningXCTest, "Test namespace should only be used in test target.")
      self.host = host
    }

    /// The number of drawings that labels haven't taken.
    var entryCount: Int {
      host.entries.count
    }

    /// The bytes that the entries' images take at most.
    var bytes: Int {
      host.bytes
    }

    /// The number of keys in the order that eviction follows.
    var evictionKeyCount: Int {
      host.order.keys.count
    }

    /// The number of links in the order that eviction follows.
    var linkCount: Int {
      host.order.links.count
    }

    /// Whether the drawing of a key is pending, which `nil` means there's no drawing for.
    func isPending(_ key: Key) -> Bool? {
      host.entries[key]?.drawing.isPending
    }

    /// Waits until the workers finish their drawings, resuming them first if they're paused.
    static func waitForDrawings() {
      workers.waitUntilIdle()
    }

    /// Waits until the workers finish their drawings, and pauses them, so that the drawings that a benchmark's step
    /// requests run between the steps instead of during them.
    static func finishDrawingsAndPause() {
      workers.finishAndPause()
    }

    /// Resumes the workers, if they're paused.
    static func resumeDrawings() {
      workers.resume()
    }

    /// The number of drawings that workers finished.
    static var finishedDrawingCount: Int {
      Drawing.finishedDrawingCount
    }

    /// Runs a body with drawing ahead of time turned off, as on a system that doesn't support it.
    static func withDrawingAheadTurnedOff(_ body: () throws -> Void) rethrows {
      TextLabelImageCache.isTurnedOff = true
      defer {
        TextLabelImageCache.isTurnedOff = false
      }
      try body()
    }
  }

  #endif
}

#endif
