//
//  SimpleTextCache.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/8/26.
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
#endif

#if canImport(UIKit)
import UIKit
#endif

/// The attributed strings of simple text that `TextNode.singleLineText` and `TextNode.multiLineText` make, kept across
/// refreshes and found by the settings that make them, with the size of each string's single line once measured.
///
/// The cache keeps two generations of strings, each of up to `generationLimit` strings and `generationByteLimit` bytes of
/// text, and empties itself when the system is low on memory.
///
/// Nodes are made and laid out on the main thread, so the cache is only used there. Its state, including what each
/// entry keeps, skips the runtime's exclusivity checks: no access to it calls the framework's code that reaches the
/// cache, so no two accesses overlap, which the compiler can't prove past the calls inside them. An assignment releases
/// what it replaces only after writing the new value, so a deinitializer that it runs sees the new value.
enum SimpleTextCache {

  /// The settings that make the attributed string of simple text.
  struct Settings {

    let text: String
    let font: Font
    let textColor: ThemedColor
    let textBackgroundColor: ThemedColor?
    let textShadow: Themed<NSShadow>?
    let textAlignment: NSTextAlignment

    /// Returns the settings with copies of their shadows, which no caller can change.
    func copyingShadows() -> Settings {
      guard let textShadow else {
        return self
      }
      return Settings(
        text: text,
        font: font,
        textColor: textColor,
        textBackgroundColor: textBackgroundColor,
        textShadow: Themed(
          light: textShadow.light.copy() as! NSShadow, // swiftlint:disable:this force_cast
          dark: textShadow.dark.copy() as! NSShadow // swiftlint:disable:this force_cast
        ),
        textAlignment: textAlignment
      )
    }
  }

  /// A text and its alignment, which key the strings.
  struct Key: Hashable {

    let text: String
    let textAlignment: NSTextAlignment

    static func == (lhs: Key, rhs: Key) -> Bool {
      lhs.textAlignment == rhs.textAlignment && hasSameCodeUnits(lhs.text, rhs.text)
    }

    func hash(into hasher: inout Hasher) {
      // the text's UTF-8 code units, as `==` compares them, where `String`'s hash is the same for canonically
      // equivalent text that `==` keeps apart, so many such texts would all land in one bucket
      let isHashed: Bool? = text.utf8.withContiguousStorageIfAvailable { codeUnits in
        hasher.combine(bytes: UnsafeRawBufferPointer(codeUnits))
        return true
      }
      if isHashed == nil {
        // a string bridged from `NSString` doesn't store contiguous UTF-8, and its code units hash the same one by one
        for codeUnit in text.utf8 {
          hasher.combine(codeUnit)
        }
      }
      // 0xFF never occurs in UTF-8, so it ends the text unambiguously
      hasher.combine(UInt8(0xFF))
      hasher.combine(textAlignment)
    }

    /// Returns whether two texts have the same UTF-8 code units.
    ///
    /// `String`'s `==` matches canonically equivalent text, such as a precomposed "é" and an "e" with a combining accent,
    /// while a text node shows its text's exact characters, so the texts are compared by their code units, in place
    /// where both texts store them contiguously.
    fileprivate static func hasSameCodeUnits(_ lhs: String, _ rhs: String) -> Bool {
      let lhsCodeUnits = lhs.utf8
      let rhsCodeUnits = rhs.utf8
      let count = lhsCodeUnits.count
      guard count == rhsCodeUnits.count else {
        return false
      }

      let isSame: Bool?? = lhsCodeUnits.withContiguousStorageIfAvailable { lhsBuffer in
        rhsCodeUnits.withContiguousStorageIfAvailable { rhsBuffer in
          // `memcmp` requires valid pointers even for no bytes, while an empty buffer's base address can be nil
          count == 0 || memcmp(lhsBuffer.baseAddress, rhsBuffer.baseAddress, count) == 0
        }
      }
      if let isSame = isSame ?? nil {
        return isSame
      } else {
        // a string bridged from `NSString` doesn't store contiguous UTF-8
        return lhsCodeUnits.elementsEqual(rhsCodeUnits)
      }
    }
  }

  /// A string with the settings that make it, the size of its single line once measured, the next entry of the same
  /// key, and the entry that the lookup after it returned.
  final class Entry {

    let text: String
    let textAlignment: NSTextAlignment
    let font: Font
    let textColor: ThemedColor
    let textBackgroundColor: ThemedColor?
    let textShadow: Themed<NSShadow>?
    let string: NSAttributedString
    var next: Entry?

    /// The entry that the lookup right after this entry's last lookup returned, which a lookup right after this entry
    /// tries first.
    @exclusivity(unchecked) var nextLookup: Entry?

    /// The number of the generation that the cache last put the entry in, see `currentGeneration`, or -1 for an entry
    /// that the cache doesn't keep.
    @exclusivity(unchecked) var generation = -1

    /// The size of the string's single line, measured once after each clearing of the text size cache.
    @exclusivity(unchecked) private var singleLineSize: CGSize?

    /// The text size cache's clear count when `singleLineSize` was measured.
    @exclusivity(unchecked) private var singleLineSizeClearCount = 0

    init(settings: Settings, string: NSAttributedString) {
      text = settings.text
      textAlignment = settings.textAlignment
      font = settings.font
      textColor = settings.textColor
      textBackgroundColor = settings.textBackgroundColor
      textShadow = settings.textShadow
      self.string = string
    }

    /// Returns the size of the string's single line, measured with a block the first time and after each clearing of
    /// the text size cache.
    func singleLineSize(measure: () -> CGSize) -> CGSize {
      if let singleLineSize, singleLineSizeClearCount == TextSizeCache.clearCount {
        return singleLineSize
      } else {
        let size = measure()
        singleLineSize = size
        singleLineSizeClearCount = TextSizeCache.clearCount
        return size
      }
    }

    /// Returns the entry of the settings in the list from this entry, if any.
    func entry(of settings: Settings) -> Entry? {
      var entry: Entry? = self
      while let candidate = entry {
        if candidate.hasSettings(settings) {
          return candidate
        }
        entry = candidate.next
      }
      return nil
    }

    /// Returns whether the entry's string is made of the settings, comparing the text and the alignment too, which a
    /// lookup in the dictionary leaves to the key.
    func isMade(of settings: Settings) -> Bool {
      textAlignment == settings.textAlignment && Key.hasSameCodeUnits(text, settings.text) && hasSettings(settings)
    }

    private func hasSettings(_ settings: Settings) -> Bool {
      Self.isSame(font, settings.font)
        && Self.isSame(textColor, settings.textColor)
        && Self.isSame(textBackgroundColor, settings.textBackgroundColor)
        && textShadow == settings.textShadow
    }

    private static func isSame(_ lhs: NSObject, _ rhs: NSObject) -> Bool {
      // by identity first, since a view's labels mostly share the objects, and comparing them calls into each object
      lhs === rhs || lhs.isEqual(rhs)
    }

    private static func isSame(_ lhs: ThemedColor, _ rhs: ThemedColor) -> Bool {
      isSame(lhs.light, rhs.light) && isSame(lhs.dark, rhs.dark)
    }

    private static func isSame(_ lhs: ThemedColor?, _ rhs: ThemedColor?) -> Bool {
      switch (lhs, rhs) {
      case (nil, nil):
        return true
      case (let lhs?, let rhs?):
        return isSame(lhs, rhs)
      case (nil, .some),
           (.some, nil):
        return false
      }
    }
  }

  /// The most strings that one generation holds.
  static let generationLimit = 4096

  /// The most text, in UTF-8 bytes, that one generation holds.
  static let generationByteLimit = 256 * 1024

  /// The strings looked up since the generations last rotated, with the strings of other settings of each key in the
  /// list of its entries.
  @exclusivity(unchecked) private static var current: [Key: Entry] = [:]

  /// The number of strings in `current`.
  @exclusivity(unchecked) private static var currentCount = 0

  /// The UTF-8 bytes of the text in `current`.
  @exclusivity(unchecked) private static var currentByteCount = 0

  /// The strings of the generation before, which a lookup moves back to `current`.
  @exclusivity(unchecked) private static var previous: [Key: Entry] = [:]

  /// Whether the cache empties itself when the system is low on memory.
  @exclusivity(unchecked) private static var isHandlingMemoryWarnings = false

  /// The number of `current`'s generation, which grows by one each time the generations rotate and each time the cache
  /// empties, so that only an entry in `current` has it.
  @exclusivity(unchecked) private static var currentGeneration = 0

  /// The entry that the last lookup of a string that the cache keeps returned.
  @exclusivity(unchecked) private static var lastLookup: Entry?

  /// Returns the entry of the settings, with the attributed string made once and then reused.
  ///
  /// - Parameter settings: The settings that make the string.
  /// - Returns: The entry of the attributed string.
  static func entry(for settings: Settings) -> Entry {
    // a layout usually looks up the same texts in the same order as the layout before, so a lookup first tries the entry
    // that followed the last lookup's entry the time before, which skips hashing the text and probing the dictionary.
    // the candidate has to be in `current`, so that an entry in `previous` moves to `current` through the dictionary
    // like any other, instead of being dropped with `previous` while it's in use
    if let candidate = lastLookup?.nextLookup, candidate.generation == currentGeneration, candidate.isMade(of: settings) {
      lastLookup = candidate
      return candidate
    }

    // the key leaves the font, the colors and the shadow to the strings' entries, since a dictionary lookup retains
    // the objects of each key that it compares with, while an entry compares them in place
    let key = Key(text: settings.text, textAlignment: settings.textAlignment)
    let entry: Entry
    if let found = current[key]?.entry(of: settings) {
      entry = found
    } else {
      entry = moveOrMakeEntry(for: settings, key: key)
    }
    // only an entry that the cache keeps is linked, since a link would keep a text over the byte limit after its node
    // lets it go
    if entry.generation == currentGeneration {
      lastLookup?.nextLookup = entry
      lastLookup = entry
    }
    return entry
  }

  /// Returns the entry of settings that `current` doesn't have, moved from `previous` or made, and keeps it in
  /// `current`.
  private static func moveOrMakeEntry(for settings: Settings, key: Key) -> Entry {
    let byteCount = settings.text.utf8.count
    guard byteCount <= generationByteLimit else {
      // a text over the byte limit isn't kept, so the limit bounds each generation however long one text is
      return Entry(settings: settings, string: makeString(for: settings))
    }

    if !isHandlingMemoryWarnings {
      isHandlingMemoryWarnings = true
      MemoryWarning.addHandler(removeAll)
    }

    let entry: Entry
    if let head = previous[key], let found = head.entry(of: settings) {
      removeFromPrevious(found, head: head, key: key)
      entry = found
    } else {
      // the entry holds copies of the shadows, since `NSShadow` is mutable, and a caller's change to a shadow would
      // otherwise change the entry's settings, and the string made of them
      let storedSettings = settings.copyingShadows()
      entry = Entry(settings: storedSettings, string: makeString(for: storedSettings))
    }

    if currentCount >= generationLimit || currentByteCount + byteCount > generationByteLimit {
      // two generations keep the strings used since the generation before, where one dictionary emptied when full
      // would drop the strings that a refresh is about to make again. the byte limit bounds long texts' memory, which
      // the count limit alone doesn't
      unlink(previous)
      previous = current
      current.removeAll(keepingCapacity: true)
      currentCount = 0
      currentByteCount = 0
      currentGeneration += 1
    }
    entry.generation = currentGeneration
    entry.next = current[key]
    current[key] = entry
    currentCount += 1
    currentByteCount += byteCount
    return entry
  }

  /// Removes an entry from the list of its key in `previous`, which starts with the head.
  private static func removeFromPrevious(_ entry: Entry, head: Entry, key: Key) {
    if head === entry {
      previous[key] = entry.next
    } else {
      var node = head
      while let next = node.next, next !== entry {
        node = next
      }
      node.next = entry.next
    }
  }

  /// Clears the links of the entries of a generation that the cache drops, so that the entries are freed, since a
  /// repeated sequence of lookups links its entries in a cycle, and a text node that keeps one of them doesn't keep the
  /// others.
  private static func unlink(_ generation: [Key: Entry]) {
    for head in generation.values {
      var entry: Entry? = head
      while let node = entry {
        entry = node.next
        node.next = nil
        node.nextLookup = nil
      }
    }
  }

  /// Returns a new attributed string made of the settings.
  private static func makeString(for settings: Settings) -> NSAttributedString {
    TextNode.attributedString(
      settings.text,
      font: settings.font,
      foregroundColor: settings.textColor,
      backgroundColor: settings.textBackgroundColor,
      shadow: settings.textShadow,
      textAlignment: settings.textAlignment,
      lineBreakMode: .byWordWrapping
    )
  }

  /// Removes all strings.
  static func removeAll() {
    unlink(current)
    unlink(previous)
    current = [:]
    currentCount = 0
    currentByteCount = 0
    previous = [:]
    currentGeneration += 1
    lastLookup = nil
  }
}
