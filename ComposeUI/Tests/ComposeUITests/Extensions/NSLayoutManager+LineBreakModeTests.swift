//
//  NSLayoutManager+LineBreakModeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/31/26.
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

import ChouTiTest

@testable import ComposeUI

class NSLayoutManager_LineBreakModeTests: XCTestCase {

  func test_setLineBreakMode_byCharWrapping_breaksEveryLineBetweenCharactersUpToTheLimit() {
    let cases: [(text: String, numberOfLines: Int, lines: [String])] = [
      (Constants.sentence, 0, ["Lorem Ipsum is simply du", "mmy text of the printing a", "nd typesetting industry."]),
      (Constants.sentence, 1, ["Lorem Ipsum is simply du"]),
      (Constants.sentence, 2, ["Lorem Ipsum is simply du", "mmy text of the printing a"]),
      (Constants.paragraphs, 2, ["First paragraph\n", "Second paragraph that is "]),
    ]
    for (text, numberOfLines, lines) in cases {
      // given: a text system with a text and a line limit
      let scenario = "\(text.prefix(5)), \(numberOfLines) lines"
      let system = TextSystem(text: text, numberOfLines: numberOfLines)

      // when: setting character wrapping
      system.layoutManager.setLineBreakMode(.byCharWrapping, in: system.textContainer)

      // then: each line breaks between characters, and the text stops at the line limit, also when the limit cuts a
      // paragraph
      expect(system.lines, scenario) == lines
    }
  }

  func test_setLineBreakMode_byCharWrapping_beforeAText_breaksTheLinesOfTheTextBetweenCharacters() {
    // given: a layout manager with a text container, without a text
    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer(size: CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude))
    textContainer.lineFragmentPadding = 0
    layoutManager.addTextContainer(textContainer)

    // when: setting character wrapping, and then giving it a text
    layoutManager.setLineBreakMode(.byCharWrapping, in: textContainer)
    let textStorage = NSTextStorage(string: Constants.sentence, attributes: [.font: Font.systemFont(ofSize: 13)])
    textStorage.addLayoutManager(layoutManager)

    // then: each line of the text breaks between characters
    expect(layoutManager.laidOutLines(in: textContainer)) == [
      "Lorem Ipsum is simply du",
      "mmy text of the printing a",
      "nd typesetting industry.",
    ]
  }

  func test_setLineBreakMode_otherModes_setHowTheLastLineEnds() {
    let cases: [(lineBreakMode: NSLineBreakMode, lines: [String])] = [
      (.byWordWrapping, ["Lorem Ipsum is simply ", "dummy text of the "]),
      (.byClipping, ["Lorem Ipsum is simply ", "dummy text of the printing and typesetting industry."]),
      (.byTruncatingHead, ["Lorem Ipsum is simply ", "…nd typesetting industry."]),
      (.byTruncatingTail, ["Lorem Ipsum is simply ", "dummy text of the printi…"]),
      (.byTruncatingMiddle, ["Lorem Ipsum is simply ", "dummy text…ing industry."]),
    ]
    for (lineBreakMode, lines) in cases {
      // given: a text system with a text in two lines
      let scenario = "\(lineBreakMode.rawValue)"
      let system = TextSystem(text: Constants.sentence, numberOfLines: 2)

      // when: setting a line break mode other than character wrapping
      system.layoutManager.setLineBreakMode(lineBreakMode, in: system.textContainer)

      // then: the text container ends the last line with it, and the lines break between words, without a delegate
      expect(system.textContainer.lineBreakMode, scenario) == lineBreakMode
      expect(system.layoutManager.delegate, scenario) == nil
      expect(system.lines, scenario) == lines
    }
  }

  func test_setLineBreakMode_fromWordWrappingToCharWrapping_laysOutTheTextAgain() {
    // given: a text system that laid out a text with word wrapping
    let system = TextSystem(text: Constants.sentence, numberOfLines: 0)
    expect(system.lines) == ["Lorem Ipsum is simply ", "dummy text of the ", "printing and typesetting ", "industry."]

    // when: setting character wrapping, which leaves the text container's line break mode as it is
    system.layoutManager.setLineBreakMode(.byCharWrapping, in: system.textContainer)

    // then: the text is laid out again, with each line breaking between characters
    expect(system.lines) == ["Lorem Ipsum is simply du", "mmy text of the printing a", "nd typesetting industry."]
  }

  func test_setLineBreakMode_fromCharWrapping_laysOutTheTextAgain() {
    for (lineBreakMode, lines) in [(NSLineBreakMode.byWordWrapping, ["Lorem Ipsum is simply ", "dummy text of the "]), (.byTruncatingTail, ["Lorem Ipsum is simply ", "dummy text of the printi…"])] {
      // given: a text system that laid out a text in two lines with character wrapping
      let scenario = "\(lineBreakMode.rawValue)"
      let system = TextSystem(text: Constants.sentence, numberOfLines: 2)
      system.layoutManager.setLineBreakMode(.byCharWrapping, in: system.textContainer)
      expect(system.lines, scenario) == ["Lorem Ipsum is simply du", "mmy text of the printing a"]

      // when: setting word wrapping, which leaves the text container's line break mode as it is, or another mode
      system.layoutManager.setLineBreakMode(lineBreakMode, in: system.textContainer)

      // then: the text is laid out again, with the lines breaking between words, and no delegate
      expect(system.lines, scenario) == lines
      expect(system.layoutManager.delegate, scenario) == nil
    }
  }

  func test_setLineBreakMode_unchanged_keepsTheLayout() {
    for lineBreakMode in [NSLineBreakMode.byCharWrapping, .byWordWrapping] {
      // given: a text system that laid out a text with a line break mode
      let scenario = "\(lineBreakMode.rawValue)"
      let system = TextSystem(text: Constants.sentence, numberOfLines: 0)
      system.layoutManager.setLineBreakMode(lineBreakMode, in: system.textContainer)
      let lines = system.lines
      expect(system.layoutManager.firstUnlaidCharacterIndex(), scenario) == system.textStorage.length

      // when: setting the same line break mode again
      system.layoutManager.setLineBreakMode(lineBreakMode, in: system.textContainer)

      // then: the text keeps its layout
      expect(system.layoutManager.firstUnlaidCharacterIndex(), scenario) == system.textStorage.length
      expect(system.lines, scenario) == lines
    }
  }

  func test_setLineBreakMode_byCharWrapping_givenAnotherDelegate_asserts() {
    // given: a text system whose layout manager has a delegate of its own
    let system = TextSystem(text: Constants.sentence, numberOfLines: 2)
    let delegate = OtherDelegate()
    system.layoutManager.delegate = delegate

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: setting character wrapping
    system.layoutManager.setLineBreakMode(.byCharWrapping, in: system.textContainer)

    // then: it asserts, and breaks the lines between characters
    expect(assertionMessages) == ["a layout manager that breaks its lines between characters must have no other delegate"]
    expect(system.lines) == ["Lorem Ipsum is simply du", "mmy text of the printing a"]
  }

  func test_setLineBreakMode_byCharWrapping_givenAnotherTextContainer_asserts() {
    // given: a text system whose layout manager has a second text container
    let system = TextSystem(text: Constants.sentence, numberOfLines: 2)
    system.layoutManager.addTextContainer(NSTextContainer(size: CGSize(width: 160, height: 100)))

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: setting character wrapping in its first text container
    system.layoutManager.setLineBreakMode(.byCharWrapping, in: system.textContainer)

    // then: it asserts, since the delegate breaks the lines of the other text container too, and breaks the lines of
    // the first one between characters
    expect(assertionMessages) == ["a layout manager that breaks its lines between characters must have only one text container, since its delegate breaks the lines of all of them"]
    expect(system.lines) == ["Lorem Ipsum is simply du", "mmy text of the printing a"]
  }

  func test_setLineBreakMode_otherModes_givenAnotherDelegate_keepTheDelegate() {
    for lineBreakMode in [NSLineBreakMode.byWordWrapping, .byTruncatingTail] {
      // given: a text system whose layout manager has a delegate of its own
      let scenario = "\(lineBreakMode.rawValue)"
      let system = TextSystem(text: Constants.sentence, numberOfLines: 2)
      let delegate = OtherDelegate()
      system.layoutManager.delegate = delegate

      // when: setting a line break mode other than character wrapping
      system.layoutManager.setLineBreakMode(lineBreakMode, in: system.textContainer)

      // then: the layout manager keeps its delegate
      expect(system.layoutManager.delegate === delegate, scenario) == true
    }
  }

  func test_measuringLineBreakMode() {
    // then: character wrapping is measured with itself, and the other modes, which break the lines before the last one
    // between words, with word wrapping
    expect(NSLineBreakMode.byCharWrapping.measuringLineBreakMode) == .byCharWrapping
    for lineBreakMode in [NSLineBreakMode.byWordWrapping, .byClipping, .byTruncatingHead, .byTruncatingTail, .byTruncatingMiddle] {
      expect(lineBreakMode.measuringLineBreakMode, "\(lineBreakMode.rawValue)") == .byWordWrapping
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// A sentence that breaks differently between characters than between words, 160 points wide.
    static let sentence = "Lorem Ipsum is simply dummy text of the printing and typesetting industry."

    /// A text of three paragraphs, whose second one takes two lines, 160 points wide.
    static let paragraphs = "First paragraph\nSecond paragraph that is a bit longer\nThird"
  }
}

/// A TextKit 1 text system that lays out a text 160 points wide, as text views and labels do, without padding.
private final class TextSystem {

  let textStorage: NSTextStorage
  let layoutManager = NSLayoutManager()
  let textContainer = NSTextContainer(size: CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude))

  init(text: String, numberOfLines: Int) {
    textStorage = NSTextStorage(string: text, attributes: [.font: Font.systemFont(ofSize: 13)])
    textContainer.lineFragmentPadding = 0
    textContainer.maximumNumberOfLines = numberOfLines
    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)
  }

  /// The lines that the text lays out in, see `laidOutLines(in:)`.
  var lines: [String] {
    layoutManager.laidOutLines(in: textContainer)
  }
}

/// A layout manager delegate of an app's own.
private final class OtherDelegate: NSObject, NSLayoutManagerDelegate {}
