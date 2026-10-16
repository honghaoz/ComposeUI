//
//  TextLabelViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/15/26.
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

class TextLabelViewTests: XCTestCase {

  // MARK: - Init

  func test_init() {
    // given: a new label view
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))

    // then: it shows no text, with no line limit, wrapping words, without an inset, clipped to its bounds, and draws its
    // text instead of updating its layer
    expect(labelView.attributedString.length) == 0
    expect(labelView.numberOfLines) == 0
    expect(labelView.lineBreakMode) == .byWordWrapping
    expect(labelView.textContainerInset) == .zero
    expect(labelView.clipsToBounds) == true
    expect(labelView.test.textContainer.lineFragmentPadding) == 0
    #if canImport(AppKit)
    expect(labelView.wantsUpdateLayer) == false
    expect(labelView.isFlipped) == true
    #endif
    #if canImport(UIKit)
    expect(labelView.isOpaque) == false
    expect(labelView.backgroundColor) == nil
    expect(labelView.contentMode) == .redraw
    #endif
  }

  // MARK: - Drawing

  func test_draw_drawsTheTextAsATextViewDoes() {
    for testCase in Self.drawingCases() {
      // given: a label view, and a text view that's neither editable nor selectable, set up as a text node set it up,
      // showing the same text with the same settings
      let labelView = Self.makeLabelView(testCase)
      let textView = Self.makeTextView(testCase)

      // when: drawing them
      let labelViewPixels = Self.pixels(of: labelView)
      let textViewPixels = Self.pixels(of: textView)

      // then: the label view draws the text, in the same pixels as the text view
      expect(Self.inkedPixelCount(labelViewPixels), testCase.name) > 0
      expect(Self.differingPixelCount(labelViewPixels, textViewPixels), testCase.name) == 0
    }
  }

  #if canImport(UIKit)
  func test_draw_link_tintColor_showsAsATextViewDoes() {
    // given: a label view and a text view with a red tint color, set before their text, which has a link
    let testCase = Self.linkCase()
    let labelView = TextLabelView(frame: CGRect(origin: .zero, size: testCase.size))
    labelView.tintColor = .red
    Self.configure(labelView, testCase)
    let textView = BaseTextView(frame: CGRect(origin: .zero, size: testCase.size))
    textView.tintColor = .red
    Self.configure(textView, testCase)

    // then: the link shows in the same pixels in both, in the tint color, except on visionOS, where a text view shows a
    // link in the system link color, whatever the tint color
    expect(Self.differingPixelCount(Self.pixels(of: labelView), Self.pixels(of: textView))) == 0
    #if os(visionOS)
    expect(Self.differingPixelCount(Self.pixels(of: labelView), Self.pixels(of: Self.makeLabelView(testCase)))) == 0
    #else
    expect(Self.differingPixelCount(Self.pixels(of: labelView), Self.pixels(of: Self.makeLabelView(testCase)))) > 0
    #endif

    // when: the tint color changes after the text is set
    labelView.tintColor = .green
    textView.tintColor = .green

    // then: the link still shows in the same pixels in both
    expect(Self.differingPixelCount(Self.pixels(of: labelView), Self.pixels(of: textView))) == 0
  }

  func test_tintColorChange_textWithoutALink_doesNotRedraw() {
    // given: a label view showing a text without a link, drawn
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    labelView.attributedString = NSAttributedString(string: "Hello", attributes: [.foregroundColor: UIColor.black])
    Self.clearNeedsDisplay(labelView)

    // when: the tint color changes
    labelView.tintColor = .red

    // then: the view doesn't draw again, since no part of its text shows in the tint color
    expect(Self.needsDisplay(labelView)) == false
  }

  func test_tintColorChange_textWithALink_redrawsWhereTheLinkFollowsTheTintColor() {
    // given: a label view showing a text with a link, drawn
    let labelView = Self.makeLabelView(Self.linkCase())
    Self.clearNeedsDisplay(labelView)

    // when: the tint color changes
    labelView.tintColor = .red

    // then: the view draws again, since its link shows in the tint color, except on visionOS, where the link shows in
    // the system link color
    #if os(visionOS)
    expect(Self.needsDisplay(labelView)) == false
    #else
    expect(Self.needsDisplay(labelView)) == true
    #endif
  }
  #endif

  // MARK: - Text

  func test_attributedString_equalText_doesNotRedraw() {
    // given: a label view showing a text, drawn
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    labelView.attributedString = NSAttributedString(string: "Hello", attributes: [.foregroundColor: Color.black])
    Self.clearNeedsDisplay(labelView)

    // when: setting an equal text, as another object
    labelView.attributedString = NSAttributedString(string: "Hello", attributes: [.foregroundColor: Color.black])

    // then: the view doesn't draw again
    expect(Self.needsDisplay(labelView)) == false

    // when: setting another text
    labelView.attributedString = NSAttributedString(string: "Hi", attributes: [.foregroundColor: Color.black])

    // then: the view shows the new text, and draws again
    expect(labelView.attributedString.string) == "Hi"
    expect(labelView.test.textStorage.string) == "Hi"
    expect(Self.needsDisplay(labelView)) == true
  }

  func test_attributedString_mutableText_keepsACopy() {
    // given: a label view showing a mutable text
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    let text = NSMutableAttributedString(string: "Hello")
    labelView.attributedString = text

    // when: the text changes after it's set
    text.mutableString.append(", world")

    // then: the view keeps the text as it was set
    expect(labelView.attributedString.string) == "Hello"
    expect(labelView.test.textStorage.string) == "Hello"

    // when: setting the changed text again
    labelView.attributedString = text

    // then: the view shows the changed text, since it compares the text with its copy of the last one
    expect(labelView.test.textStorage.string) == "Hello, world"
  }

  // MARK: - Settings

  func test_settings_redraw() {
    // given: a label view showing a text, drawn
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    labelView.attributedString = NSAttributedString(string: "Hello, world", attributes: [.foregroundColor: Color.black])
    Self.clearNeedsDisplay(labelView)

    // when: changing the number of lines
    labelView.numberOfLines = 1

    // then: the text container takes it, and the view draws again
    expect(labelView.test.textContainer.maximumNumberOfLines) == 1
    expect(Self.needsDisplay(labelView)) == true

    // when: changing the line break mode
    Self.clearNeedsDisplay(labelView)
    labelView.lineBreakMode = .byTruncatingTail

    // then: the text container takes it, and the view draws again
    expect(labelView.test.textContainer.lineBreakMode) == .byTruncatingTail
    expect(Self.needsDisplay(labelView)) == true

    // when: changing the inset
    Self.clearNeedsDisplay(labelView)
    labelView.textContainerInset = CGSize(width: 4, height: 2)

    // then: the view draws again, which fits the text container in the bounds inside the inset
    expect(Self.needsDisplay(labelView)) == true
    _ = Self.pixels(of: labelView)
    expect(labelView.test.textContainer.size) == CGSize(width: 92, height: 36)
  }

  func test_numberOfLines_negative_hasNoLimit() {
    // given: a label view
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))

    // when: setting a negative number of lines
    labelView.numberOfLines = -1

    // then: the text container has no line limit
    expect(labelView.test.textContainer.maximumNumberOfLines) == 0
  }

  func test_draw_insetLargerThanTheBounds_drawsNothing() {
    // given: a label view whose inset leaves no room for the text
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    labelView.textContainerInset = CGSize(width: 6, height: 6)
    labelView.attributedString = NSAttributedString(string: "Hello", attributes: [.foregroundColor: Color.black])

    // when: drawing it
    let pixels = Self.pixels(of: labelView)

    // then: the text container is empty, and the view draws nothing
    expect(labelView.test.textContainer.size) == .zero
    expect(Self.inkedPixelCount(pixels)) == 0
  }

  #if canImport(AppKit)
  func test_setFrameSize_redrawsWhenResized() {
    // given: a label view showing a text, drawn
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    labelView.attributedString = NSAttributedString(string: "Hello", attributes: [.foregroundColor: Color.black])
    Self.clearNeedsDisplay(labelView)

    // when: moving it, and setting the same size
    labelView.setFrameOrigin(CGPoint(x: 10, y: 10))
    labelView.setFrameSize(CGSize(width: 100, height: 20))

    // then: the view doesn't draw again
    expect(Self.needsDisplay(labelView)) == false

    // when: resizing it
    labelView.setFrameSize(CGSize(width: 120, height: 20))

    // then: the view draws again
    expect(Self.needsDisplay(labelView)) == true
  }
  #endif

  #if canImport(UIKit)
  func test_frame_redrawsWhenResized() {
    // given: a label view showing a text, drawn
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    labelView.attributedString = NSAttributedString(string: "Hello", attributes: [.foregroundColor: UIColor.black])
    Self.clearNeedsDisplay(labelView)

    // when: moving it
    labelView.frame = CGRect(x: 10, y: 10, width: 100, height: 20)

    // then: the view doesn't draw again
    expect(Self.needsDisplay(labelView)) == false

    // when: resizing it
    labelView.frame = CGRect(x: 10, y: 10, width: 120, height: 20)

    // then: the view draws again
    expect(Self.needsDisplay(labelView)) == true
  }
  #endif

  // MARK: - Appearance

  func test_appearanceChange_drawsTheDynamicColorsOfTheNewAppearance() {
    // given: a label view in a window in the light appearance, showing a text in the label color, drawn
    let window = TestWindow()
    #if canImport(AppKit)
    window.appearance = NSAppearance(named: .aqua)
    let labelColor = NSColor.labelColor
    #endif
    #if canImport(UIKit)
    window.overrideUserInterfaceStyle = .light
    window.isHidden = false
    let labelColor = UIColor.label
    #endif
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 140, height: 30))
    labelView.numberOfLines = 1
    labelView.attributedString = NSAttributedString(string: "Label color", attributes: [.font: Font.systemFont(ofSize: 20), .foregroundColor: labelColor])
    window.contentView().addSubview(labelView)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    CATransaction.flush()
    expect(Self.averageInkedBrightness(Self.drawnPixels(of: labelView))) < 64
    #if canImport(AppKit)
    expect(Self.needsDisplay(labelView)) == false
    #endif

    // when: the window changes to the dark appearance
    #if canImport(AppKit)
    window.appearance = NSAppearance(named: .darkAqua)
    #endif
    #if canImport(UIKit)
    window.overrideUserInterfaceStyle = .dark
    #endif

    // then: AppKit marks the view to draw again, while UIKit marks it in its next layout pass, and rendering a layer-backed
    // AppKit view draws it instead of showing its contents
    #if canImport(AppKit)
    expect(Self.needsDisplay(labelView)) == true
    #endif

    // when: the run loop turns
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    // then: the view draws its text again, in the dark appearance's label color
    expect(Self.averageInkedBrightness(Self.drawnPixels(of: labelView))) > 192
  }

  // MARK: - Accessibility

  #if canImport(AppKit)
  func test_accessibility_isStaticTextWithTheTextAsItsValue() {
    // given: a label view showing a text
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    labelView.attributedString = NSAttributedString(string: "Hello")

    // then: it's a static text element, whose value is the text
    expect(labelView.isAccessibilityElement()) == true
    expect(labelView.accessibilityRole()) == .staticText
    expect(labelView.accessibilityValue() as? String) == "Hello"

    // when: an app sets its own value
    labelView.setAccessibilityValue("Greeting")

    // then: the app's value wins
    expect(labelView.accessibilityValue() as? String) == "Greeting"
  }

  func test_accessibility_characters_describeTheText() throws {
    // given: a label view showing a text with an emoji, which takes two UTF-16 units, and a bold run before it
    let text = NSMutableAttributedString(string: "Hi ", attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
    text.append(NSAttributedString(string: "😀 there", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
    labelView.attributedString = text

    // then: the queries describe the text's characters, the emoji as one character, and its style runs
    expect(labelView.accessibilityNumberOfCharacters()) == 11
    expect(labelView.accessibilityString(for: NSRange(location: 3, length: 2))) == "😀"
    expect(labelView.accessibilityString(for: NSRange(location: 11, length: 0))) == ""
    expect(labelView.accessibilityRange(for: 4)) == NSRange(location: 3, length: 2)
    expect(labelView.accessibilityRange(for: 0)) == NSRange(location: 0, length: 1)
    expect(labelView.accessibilityStyleRange(for: 1)) == NSRange(location: 0, length: 3)
    expect(labelView.accessibilityStyleRange(for: 6)) == NSRange(location: 3, length: 8)
    let rtf = try labelView.accessibilityRTF(for: NSRange(location: 6, length: 5)).unwrap()
    expect(try NSAttributedString(rtf: rtf, documentAttributes: nil).unwrap().string) == "there"

    // then: a range or an index outside the text describes nothing, including a range that would overflow
    let notFound = NSRange(location: NSNotFound, length: 0)
    for range in [NSRange(location: 10, length: 2), NSRange(location: 12, length: 0), NSRange(location: NSNotFound, length: 1), NSRange(location: -1, length: 1)] {
      expect(labelView.accessibilityString(for: range), "\(range)") == nil
      expect(labelView.accessibilityAttributedString(for: range), "\(range)") == nil
      expect(labelView.accessibilityRTF(for: range), "\(range)") == nil
      expect(labelView.accessibilityFrame(for: range), "\(range)") == .zero
    }
    for index in [-1, 11] {
      expect(labelView.accessibilityRange(for: index), "\(index)") == notFound
      expect(labelView.accessibilityStyleRange(for: index), "\(index)") == notFound
    }
  }

  func test_accessibilityAttributedString_hasTheAttributesOfANativeLabel() throws {
    // given: a label view and a native label showing a text with a font, a color and a language for a part
    let text = NSMutableAttributedString(string: "Bonjour, world", attributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.red])
    text.addAttribute(.accessibilityLanguage, value: "fr-FR", range: NSRange(location: 0, length: 7))
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
    labelView.attributedString = text
    let nativeLabel = NSTextField(labelWithAttributedString: text)
    let nativeCell = try nativeLabel.cell.unwrap()

    for range in [NSRange(location: 0, length: 14), NSRange(location: 3, length: 8)] {
      // then: the attributed string is in the attributes that assistive technologies read, as a native label's
      let attributedString = try labelView.accessibilityAttributedString(for: range).unwrap()
      expect(attributedString, "\(range)") == nativeCell.accessibilityAttributedString(for: range)
      expect(attributedString.attribute(.accessibilityFont, at: 0, effectiveRange: nil), "\(range)") != nil
    }
  }

  func test_accessibility_lines_followTheLayout() throws {
    // given: a label view showing three paragraphs
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    labelView.attributedString = NSAttributedString(string: "One\nTwo\nThree", attributes: [.font: NSFont.systemFont(ofSize: 13)])

    // then: each paragraph is a line, and an index past the text is on the last line
    expect(labelView.accessibilityRange(forLine: 0)) == NSRange(location: 0, length: 4)
    expect(labelView.accessibilityRange(forLine: 1)) == NSRange(location: 4, length: 4)
    expect(labelView.accessibilityRange(forLine: 2)) == NSRange(location: 8, length: 5)
    expect(labelView.accessibilityRange(forLine: 3)) == NSRange(location: NSNotFound, length: 0)
    expect([0, 3, 4, 7, 8, 12, 13].map { labelView.accessibilityLine(for: $0) }) == [0, 0, 1, 1, 2, 2, 2]
    expect(labelView.accessibilityVisibleCharacterRange()) == NSRange(location: 0, length: 13)

    // when: the view shows one line
    labelView.numberOfLines = 1

    // then: only the first line is laid out and visible, and an index past it is on that line
    expect(labelView.accessibilityVisibleCharacterRange()) == NSRange(location: 0, length: 4)
    expect(labelView.accessibilityRange(forLine: 1)) == NSRange(location: NSNotFound, length: 0)
    expect(labelView.accessibilityLine(for: 10)) == 0

    // when: the view shows a text that wraps in its width, which fits each word but not both
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13)]
    let wordWidth = max(NSAttributedString(string: "Hello", attributes: attributes).size().width, NSAttributedString(string: "world", attributes: attributes).size().width)
    labelView.frame.size.width = ceil(wordWidth) + 2
    labelView.numberOfLines = 0
    labelView.attributedString = NSAttributedString(string: "Hello world", attributes: attributes)

    // then: each line that the text wraps into is a line
    expect(labelView.accessibilityRange(forLine: 0)) == NSRange(location: 0, length: 6)
    expect(labelView.accessibilityRange(forLine: 1)) == NSRange(location: 6, length: 5)
    expect(labelView.accessibilityLine(for: 7)) == 1

    // when: the inset leaves no room for the text
    labelView.textContainerInset = CGSize(width: 0, height: 60)

    // then: no line is laid out or visible
    expect(labelView.accessibilityVisibleCharacterRange()) == NSRange(location: 0, length: 0)
    expect(labelView.accessibilityRange(forLine: 0)) == NSRange(location: NSNotFound, length: 0)
    expect(labelView.accessibilityLine(for: 0)) == 0
    expect(labelView.accessibilityFrame(for: NSRange(location: 0, length: 1))) == .zero
  }

  func test_accessibility_geometry_isOnTheScreen() throws {
    // given: a label view with an inset in a window, showing a text with an emoji
    let window = TestWindow()
    let labelView = TextLabelView(frame: CGRect(x: 30, y: 40, width: 200, height: 40))
    labelView.textContainerInset = CGSize(width: 6, height: 4)
    labelView.attributedString = NSAttributedString(string: "Hi 😀 there", attributes: [.font: NSFont.systemFont(ofSize: 13)])
    try window.contentView.unwrap().addSubview(labelView)
    let viewFrameOnScreen = window.convertToScreen(labelView.convert(labelView.bounds, to: nil))

    // then: a range's frame is where its glyphs are laid out inside the inset, on the screen, so the first character
    // starts at the inset from the view's top left corner
    let firstFrame = labelView.accessibilityFrame(for: NSRange(location: 0, length: 1))
    expect(firstFrame.minX) == viewFrameOnScreen.minX + 6
    expect(firstFrame.maxY) == viewFrameOnScreen.maxY - 4
    let glyphRange = labelView.test.layoutManager.glyphRange(forCharacterRange: NSRange(location: 6, length: 5), actualCharacterRange: nil)
    let wordRect = labelView.test.layoutManager.boundingRect(forGlyphRange: glyphRange, in: labelView.test.textContainer).offsetBy(dx: 6, dy: 4)
    expect(labelView.accessibilityFrame(for: NSRange(location: 6, length: 5))) == window.convertToScreen(labelView.convert(wordRect, to: nil))

    // then: the range at a point on the screen is the character there, the emoji as one character
    let emojiFrame = labelView.accessibilityFrame(for: NSRange(location: 3, length: 2))
    expect(labelView.accessibilityRange(for: NSPoint(x: emojiFrame.midX, y: emojiFrame.midY))) == NSRange(location: 3, length: 2)
    let wordFrame = labelView.accessibilityFrame(for: NSRange(location: 6, length: 5))
    expect(labelView.accessibilityRange(for: NSPoint(x: wordFrame.minX + 1, y: wordFrame.midY))) == NSRange(location: 6, length: 1)

    // when: the inset leaves no room for the text
    labelView.textContainerInset = CGSize(width: 0, height: 20)

    // then: no point is on a character
    expect(labelView.accessibilityRange(for: NSPoint(x: emojiFrame.midX, y: emojiFrame.midY))) == NSRange(location: NSNotFound, length: 0)

    // when: the view has no text, or isn't in a window
    labelView.textContainerInset = .zero
    labelView.attributedString = NSAttributedString()
    let emptyRange = labelView.accessibilityRange(for: NSPoint(x: emojiFrame.midX, y: emojiFrame.midY))
    labelView.attributedString = NSAttributedString(string: "Hi")
    labelView.removeFromSuperview()

    // then: no point is on a character
    expect(emptyRange) == NSRange(location: NSNotFound, length: 0)
    expect(labelView.accessibilityRange(for: NSPoint(x: emojiFrame.midX, y: emojiFrame.midY))) == NSRange(location: NSNotFound, length: 0)
  }

  func test_accessibility_appValue_leavesTheTextQueriesToTheView() {
    // given: a label view showing a text, with an app's own value, and a plain view with the same value
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
    labelView.attributedString = NSAttributedString(string: "One\nTwo")
    labelView.setAccessibilityValue("Greeting")
    let plainView = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
    plainView.setAccessibilityValue("Greeting")

    // then: the text queries answer as a view's do, instead of describing the text, which isn't the value
    let range = NSRange(location: 0, length: 3)
    expect(labelView.accessibilityNumberOfCharacters()) == plainView.accessibilityNumberOfCharacters()
    expect(labelView.accessibilityVisibleCharacterRange()) == plainView.accessibilityVisibleCharacterRange()
    expect(labelView.accessibilityString(for: range)) == plainView.accessibilityString(for: range)
    expect(labelView.accessibilityAttributedString(for: range)) == plainView.accessibilityAttributedString(for: range)
    expect(labelView.accessibilityRTF(for: range)) == plainView.accessibilityRTF(for: range)
    expect(labelView.accessibilityRange(for: 1)) == plainView.accessibilityRange(for: 1)
    expect(labelView.accessibilityStyleRange(for: 1)) == plainView.accessibilityStyleRange(for: 1)
    expect(labelView.accessibilityLine(for: 5)) == plainView.accessibilityLine(for: 5)
    expect(labelView.accessibilityRange(forLine: 1)) == plainView.accessibilityRange(forLine: 1)
    expect(labelView.accessibilityFrame(for: range)) == plainView.accessibilityFrame(for: range)
    expect(labelView.accessibilityRange(for: NSPoint(x: 5, y: 5))) == plainView.accessibilityRange(for: NSPoint(x: 5, y: 5))
    expect(labelView.accessibilityNumberOfCharacters()) != 7
  }
  #endif

  #if canImport(UIKit)
  func test_accessibility_isStaticTextLabeledByTheText() {
    // given: a label view showing a text
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    labelView.attributedString = NSAttributedString(string: "Hello")

    // then: it's a static text element, labeled by the text
    expect(labelView.isAccessibilityElement) == true
    expect(labelView.accessibilityTraits) == .staticText
    expect(labelView.accessibilityLabel) == "Hello"

    // when: an app sets its own label
    labelView.accessibilityLabel = "Greeting"

    // then: the app's label wins
    expect(labelView.accessibilityLabel) == "Greeting"

    // when: the app removes its label
    labelView.accessibilityLabel = nil

    // then: the text labels the view again
    expect(labelView.accessibilityLabel) == "Hello"
  }

  func test_accessibilityAttributedLabel_isTheTextWithItsAttributes() {
    // given: a label view showing a text with a part to speak in French
    let text = NSMutableAttributedString(string: "Bonjour, world")
    text.addAttribute(.accessibilitySpeechLanguage, value: "fr-FR", range: NSRange(location: 0, length: 7))
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    labelView.attributedString = text

    // then: the attributed label is the text, with the language to speak the part in
    expect(labelView.accessibilityAttributedLabel?.string) == "Bonjour, world"
    expect(labelView.accessibilityAttributedLabel?.attribute(.accessibilitySpeechLanguage, at: 0, effectiveRange: nil) as? String) == "fr-FR"

    // when: an app sets its own label
    labelView.accessibilityLabel = "Greeting"

    // then: the app's label wins, as an attributed label too
    expect(labelView.accessibilityAttributedLabel) == NSAttributedString(string: "Greeting")

    // when: an app sets its own attributed label
    let appLabel = NSAttributedString(string: "Salut", attributes: [.accessibilitySpeechLanguage: "fr-CA"])
    labelView.accessibilityAttributedLabel = appLabel

    // then: the app's attributed label wins, as a label too
    expect(labelView.accessibilityAttributedLabel) == appLabel
    expect(labelView.accessibilityLabel) == "Salut"

    // when: the app removes its label
    labelView.accessibilityAttributedLabel = nil

    // then: the text labels the view again, with its attributes
    expect(labelView.accessibilityAttributedLabel) == text
    expect(labelView.accessibilityLabel) == "Bonjour, world"
  }
  #endif

  // MARK: - Hit Testing

  func test_hitTest_takesNoClicksOrTouches() {
    // given: a label view showing a text
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    labelView.attributedString = NSAttributedString(string: "Hello")

    // then: it takes no clicks or touches in its bounds, as a text view that's neither editable nor selectable
    #if canImport(AppKit)
    expect(labelView.hitTest(CGPoint(x: 10, y: 10))) == nil
    #endif
    #if canImport(UIKit)
    expect(labelView.isUserInteractionEnabled) == false
    expect(labelView.hitTest(CGPoint(x: 10, y: 10), with: nil)) == nil
    #endif
  }

  // MARK: - Reuse

  func test_resetForReuse_keepsTheSettingsAndTheTextUntilTheEndOfTheRunLoopTurn() {
    // given: a label view with settings, a text, and the record of the text that a text node applied a theme to
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    let text = NSAttributedString(string: "Hello")
    labelView.numberOfLines = 2
    labelView.lineBreakMode = .byTruncatingTail
    labelView.textContainerInset = CGSize(width: 4, height: 2)
    labelView.attributedString = text
    labelView.lastThemedText = (text, .light, text)
    let countBefore = BaseTextView.scheduledTextRemovalCount

    // when: resetting it for a reuse by a text node
    labelView.resetForReuse()

    // then: it keeps the settings and the text, which it removes at the end of the run loop turn, and forgets the themed
    // text
    expect(labelView.numberOfLines) == 2
    expect(labelView.lineBreakMode) == .byTruncatingTail
    expect(labelView.textContainerInset) == CGSize(width: 4, height: 2)
    expect(labelView.attributedString.string) == "Hello"
    expect(labelView.lastThemedText == nil) == true
    expect(BaseTextView.scheduledTextRemovalCount) == countBefore + 1

    // when: the run loop turn ends
    Self.waitForTheEndOfTheRunLoopTurn(self)

    // then: the text is gone, and the settings stay
    expect(labelView.attributedString.length) == 0
    expect(labelView.test.textStorage.length) == 0
    expect(labelView.numberOfLines) == 2
    expect(BaseTextView.scheduledTextRemovalCount) == 0
  }

  func test_resetForReuse_newTextInTheSameTurn_keepsTheNewText() {
    // given: a label view showing a text, reset for a reuse by a text node
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    labelView.attributedString = NSAttributedString(string: "Hello")
    labelView.resetForReuse()

    // when: the reuse sets another text in the same run loop turn, and the turn ends
    labelView.attributedString = NSAttributedString(string: "Hi")
    Self.waitForTheEndOfTheRunLoopTurn(self)

    // then: the view keeps the new text
    expect(labelView.attributedString.string) == "Hi"
    expect(labelView.test.textStorage.string) == "Hi"
  }

  // MARK: - Measurement

  func test_draw_inTheSizeThatComposeUIMeasures_laysOutTheWholeText() {
    let font = Font.systemFont(ofSize: 15)
    let spaced: NSParagraphStyle = {
      let style = NSMutableParagraphStyle()
      style.lineSpacing = 4
      return style
    }()
    let cases: [(name: String, text: NSAttributedString, width: CGFloat, numberOfLines: Int)] = [
      ("single line", NSAttributedString(string: "A single line of text", attributes: [.font: font]), 1000, 1),
      ("wrapped", NSAttributedString(string: "A paragraph that wraps across several lines in a narrow view.", attributes: [.font: font]), 140, 0),
      ("line spacing", NSAttributedString(string: "A paragraph with line spacing that wraps across several lines.", attributes: [.font: font, .paragraphStyle: spaced]), 140, 0),
      ("right to left", NSAttributedString(string: "مرحبا بالعالم، هذا نص عربي طويل يلتف عبر عدة أسطر", attributes: [.font: font]), 140, 0),
    ]
    for testCase in cases {
      // given: a label view in the size that ComposeUI measures for the text, as a text node of a fixed size has
      let size = testCase.text.boundingRectSize(numberOfLines: testCase.numberOfLines, layoutWidth: testCase.width).roundedUp(scaleFactor: 1)
      let labelView = TextLabelView(frame: CGRect(origin: .zero, size: size))
      labelView.numberOfLines = testCase.numberOfLines
      labelView.lineBreakMode = .byTruncatingTail
      labelView.attributedString = testCase.text

      // when: drawing it
      _ = Self.pixels(of: labelView)

      // then: it lays out the whole text, without truncating its last line
      let layoutManager = labelView.test.layoutManager
      let glyphRange = layoutManager.glyphRange(for: labelView.test.textContainer)
      expect(layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil).length, testCase.name) == testCase.text.length
      expect(layoutManager.truncatedGlyphRange(inLineFragmentForGlyphAt: NSMaxRange(glyphRange) - 1).location, testCase.name) == NSNotFound
    }
  }

  // MARK: - Helpers

  private struct DrawingCase {
    let name: String
    let text: NSAttributedString
    let size: CGSize
    let numberOfLines: Int
    let lineBreakMode: NSLineBreakMode
    let inset: CGSize
  }

  /// Returns a text with a link in the middle of it, between runs without a link.
  private static func linkCase() -> DrawingCase {
    let text = NSMutableAttributedString(string: "Visit the link here", attributes: [.font: Font.systemFont(ofSize: 15), .foregroundColor: Color.black])
    text.addAttribute(.link, value: URL(string: "https://example.com")!, range: NSRange(location: 10, length: 4)) // swiftlint:disable:this force_unwrapping
    return DrawingCase(
      name: "link",
      text: text,
      size: CGSize(width: 140, height: 30),
      numberOfLines: 1,
      lineBreakMode: .byTruncatingTail,
      inset: .zero
    )
  }

  /// Returns texts and settings that cover the attributes and the layouts that a text view draws.
  private static func drawingCases() -> [DrawingCase] {
    let font = Font.systemFont(ofSize: 15)
    let black = Color.black
    let centered: NSParagraphStyle = {
      let style = NSMutableParagraphStyle()
      style.alignment = .center
      style.lineSpacing = 4
      style.paragraphSpacing = 6
      return style
    }()
    let shadow = NSShadow()
    shadow.shadowColor = Color.red
    shadow.shadowOffset = CGSize(width: 1, height: 1)
    shadow.shadowBlurRadius = 1
    let attachment = NSTextAttachment()
    #if canImport(AppKit)
    attachment.image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
      NSColor.blue.setFill()
      rect.fill()
      return true
    }
    let labelColor = NSColor.labelColor
    #endif
    #if canImport(UIKit)
    attachment.image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
      UIColor.blue.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
    }
    let labelColor = UIColor.label
    #endif
    let withAttachment = NSMutableAttributedString(string: "Image ", attributes: [.font: font, .foregroundColor: black])
    withAttachment.append(NSAttributedString(attachment: attachment))
    withAttachment.append(NSAttributedString(string: " after", attributes: [.font: font, .foregroundColor: black]))
    let decorations: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: black,
      .backgroundColor: Color.yellow,
      .underlineStyle: NSUnderlineStyle.single.rawValue,
      .strikethroughStyle: NSUnderlineStyle.single.rawValue,
    ]
    let strokeAndOffset: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: black,
      .strokeColor: Color.red,
      .strokeWidth: -2,
      .baselineOffset: 3,
      .obliqueness: 0.2,
    ]
    let narrow = CGSize(width: 140, height: 80)
    let line = CGSize(width: 140, height: 30)
    return [
      DrawingCase(name: "wrapped", text: NSAttributedString(string: "A paragraph that wraps across several lines in a narrow view.", attributes: [.font: font, .foregroundColor: black]), size: narrow, numberOfLines: 0, lineBreakMode: .byWordWrapping, inset: .zero),
      DrawingCase(name: "truncated", text: NSAttributedString(string: "A paragraph that is truncated at the end of its second line because it is long.", attributes: [.font: font, .foregroundColor: black]), size: CGSize(width: 140, height: 36), numberOfLines: 2, lineBreakMode: .byTruncatingTail, inset: .zero),
      DrawingCase(name: "right to left", text: NSAttributedString(string: "مرحبا بالعالم، هذا نص عربي طويل يلتف عبر عدة أسطر", attributes: [.font: font, .foregroundColor: black]), size: narrow, numberOfLines: 0, lineBreakMode: .byWordWrapping, inset: .zero),
      DrawingCase(name: "inset", text: NSAttributedString(string: "Inset text", attributes: [.font: Font.boldSystemFont(ofSize: 17), .foregroundColor: Color.red]), size: CGSize(width: 140, height: 40), numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: CGSize(width: 6, height: 4)),
      DrawingCase(name: "decorations", text: NSAttributedString(string: "Background underline strike", attributes: decorations), size: CGSize(width: 140, height: 60), numberOfLines: 0, lineBreakMode: .byWordWrapping, inset: .zero),
      DrawingCase(name: "stroke and offset", text: NSAttributedString(string: "Stroked, raised, slanted", attributes: strokeAndOffset), size: CGSize(width: 140, height: 60), numberOfLines: 0, lineBreakMode: .byWordWrapping, inset: .zero),
      DrawingCase(name: "shadow", text: NSAttributedString(string: "Shadowed text", attributes: [.font: font, .foregroundColor: black, .shadow: shadow]), size: line, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero),
      DrawingCase(name: "paragraph style", text: NSAttributedString(string: "Centered with spacing\nSecond paragraph here", attributes: [.font: font, .foregroundColor: black, .paragraphStyle: centered]), size: CGSize(width: 140, height: 90), numberOfLines: 0, lineBreakMode: .byWordWrapping, inset: .zero),
      linkCase(),
      DrawingCase(name: "attachment", text: withAttachment, size: line, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero),
      DrawingCase(name: "no attributes", text: NSAttributedString(string: "Plain text without attributes"), size: CGSize(width: 140, height: 40), numberOfLines: 0, lineBreakMode: .byWordWrapping, inset: .zero),
      DrawingCase(name: "emoji and kern", text: NSAttributedString(string: "Emoji 😀🎉 kern", attributes: [.font: font, .foregroundColor: black, .kern: 1.5]), size: line, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero),
      DrawingCase(name: "dynamic color", text: NSAttributedString(string: "Label color text", attributes: [.font: font, .foregroundColor: labelColor]), size: line, numberOfLines: 1, lineBreakMode: .byTruncatingTail, inset: .zero),
      DrawingCase(name: "taller than the bounds", text: NSAttributedString(string: "Line one\nLine two\nLine three", attributes: [.font: font, .foregroundColor: black]), size: CGSize(width: 140, height: 46), numberOfLines: 0, lineBreakMode: .byTruncatingTail, inset: CGSize(width: 0, height: 4)),
    ]
  }

  private static func makeLabelView(_ testCase: DrawingCase) -> TextLabelView {
    let labelView = TextLabelView(frame: CGRect(origin: .zero, size: testCase.size))
    configure(labelView, testCase)
    return labelView
  }

  private static func configure(_ labelView: TextLabelView, _ testCase: DrawingCase) {
    labelView.numberOfLines = testCase.numberOfLines
    labelView.lineBreakMode = testCase.lineBreakMode
    labelView.textContainerInset = testCase.inset
    labelView.attributedString = testCase.text
  }

  /// Returns a text view that's neither editable nor selectable, set up as a text node set up such a text view.
  private static func makeTextView(_ testCase: DrawingCase) -> BaseTextView {
    let textView = BaseTextView(frame: CGRect(origin: .zero, size: testCase.size))
    configure(textView, testCase)
    return textView
  }

  private static func configure(_ textView: BaseTextView, _ testCase: DrawingCase) {
    #if !os(tvOS)
    textView.isEditable = false
    #endif
    textView.isSelectable = false
    #if canImport(AppKit)
    textView.ignoreHitTest = true
    textView.attributedString = testCase.text
    textView.numberOfLines = testCase.numberOfLines
    textView.lineBreakMode = testCase.lineBreakMode
    textView.textContainerInset = testCase.inset
    #endif
    #if canImport(UIKit)
    textView.isUserInteractionEnabled = false
    textView.isScrollEnabled = false
    textView.numberOfLines = testCase.numberOfLines
    textView.lineBreakMode = testCase.lineBreakMode
    textView.textContainerInset = UIEdgeInsets(top: testCase.inset.height, left: testCase.inset.width, bottom: testCase.inset.height, right: testCase.inset.width)
    textView.attributedString = testCase.text
    textView.layoutIfNeeded()
    #endif
  }

  /// Returns the RGBA pixels that a view draws, at a scale of 2.
  private static func pixels(of view: View) -> [UInt8] {
    #if canImport(AppKit)
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)! // swiftlint:disable:this force_unwrapping
    view.cacheDisplay(in: view.bounds, to: rep)
    return pixels(width: rep.pixelsWide, height: rep.pixelsHigh) { context in
      context.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)) // swiftlint:disable:this force_unwrapping
    }
    #endif
    #if canImport(UIKit)
    return drawnPixels(of: view)
    #endif
  }

  /// Returns the RGBA pixels of the contents that a view's layer shows, at a scale of 2.
  private static func drawnPixels(of view: View) -> [UInt8] {
    let width = Int(view.bounds.width * 2)
    let height = Int(view.bounds.height * 2)
    return pixels(width: width, height: height) { context in
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 2, y: -2)
      view.layer().render(in: context)
    }
  }

  private static func pixels(width: Int, height: Int, draw: (CGContext) -> Void) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: width * height * 4)
    data.withUnsafeMutableBytes { buffer in
      let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)! // swiftlint:disable:this force_unwrapping
      draw(context)
    }
    return data
  }

  private static func inkedPixelCount(_ pixels: [UInt8]) -> Int {
    stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 0 }.count
  }

  /// Returns the number of pixels that differ between two drawings, or `Int.max` for drawings of different sizes.
  private static func differingPixelCount(_ first: [UInt8], _ second: [UInt8]) -> Int {
    guard first.count == second.count else {
      return Int.max
    }
    return stride(from: 0, to: first.count, by: 4).filter { index in
      (0 ..< 4).contains { first[index + $0] != second[index + $0] }
    }.count
  }

  /// Returns the average brightness of the pixels that are mostly opaque, from 0 to 255.
  private static func averageInkedBrightness(_ pixels: [UInt8]) -> Int {
    let inked = stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0 + 3] > 200 }
    guard !inked.isEmpty else {
      return -1
    }
    let total = inked.reduce(0) { $0 + Int(pixels[$1]) + Int(pixels[$1 + 1]) + Int(pixels[$1 + 2]) }
    return total / (inked.count * 3)
  }

  /// Returns whether the view's layer needs to draw, which a layer-backed AppKit view, as a UIKit view, asks its layer
  /// for, while the view's `needsDisplay` doesn't tell.
  private static func needsDisplay(_ view: TextLabelView) -> Bool {
    view.layer().needsDisplay()
  }

  /// Draws the view's layer, if it needs to draw.
  private static func clearNeedsDisplay(_ view: TextLabelView) {
    view.layer().displayIfNeeded()
  }

  private static func waitForTheEndOfTheRunLoopTurn(_ testCase: XCTestCase) {
    let turnEnded = testCase.expectation(description: "the run loop turn ends")
    onNextRunLoop {
      turnEnded.fulfill()
    }
    testCase.wait(for: [turnEnded], timeout: 1)
  }
}
