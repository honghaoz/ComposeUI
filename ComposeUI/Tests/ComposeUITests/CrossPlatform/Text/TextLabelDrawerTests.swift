//
//  TextLabelDrawerTests.swift
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
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

@testable import ComposeUI

class TextLabelDrawerTests: XCTestCase {

  func test_init_setsUpTheTextKitObjects() {
    // given: a new drawer
    let drawer = TextLabelDrawer()

    // then: the storage has the layout manager, which has the container, which lays out the text without padding
    expect(drawer.textStorage.layoutManagers.first) === drawer.layoutManager
    expect(drawer.layoutManager.textContainers.first) === drawer.textContainer
    expect(drawer.textContainer.lineFragmentPadding) == 0
    #if canImport(AppKit)
    expect(drawer.layoutManager.backgroundLayoutEnabled) == false
    #endif
  }

  func test_shownText_showsEachParagraphInTheDirectionOfItsText() {
    // given: a text in a right-to-left script, without a writing direction
    let text = NSAttributedString(string: "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}")

    // when: getting the text that a label shows for it
    let shownText = TextLabelDrawer.shownText(of: text)

    // then: the paragraph is shown right to left
    let style = shownText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    expect(style?.baseWritingDirection) == .rightToLeft
    expect(shownText.string) == text.string
  }

  func test_numberOfLines() {
    // given: a drawer
    let drawer = TextLabelDrawer()

    // when: setting a number of lines
    drawer.numberOfLines = 2

    // then: the container lays out up to that many lines
    expect(drawer.numberOfLines) == 2
    expect(drawer.textContainer.maximumNumberOfLines) == 2

    // when: setting the same number again
    drawer.numberOfLines = 2

    // then: the container keeps it
    expect(drawer.textContainer.maximumNumberOfLines) == 2

    // when: setting a negative number
    drawer.numberOfLines = -1

    // then: the container has no line limit
    expect(drawer.numberOfLines) == 0
  }

  func test_lineBreakMode() {
    // given: a drawer
    let drawer = TextLabelDrawer()

    // when: setting a line break mode
    drawer.lineBreakMode = .byTruncatingMiddle

    // then: the container breaks the last line with it
    expect(drawer.lineBreakMode) == .byTruncatingMiddle
    expect(drawer.textContainer.lineBreakMode) == .byTruncatingMiddle

    // when: setting the same mode again
    drawer.lineBreakMode = .byTruncatingMiddle

    // then: the container keeps it
    expect(drawer.textContainer.lineBreakMode) == .byTruncatingMiddle
  }

  func test_fitTextContainer() {
    // given: a drawer
    let drawer = TextLabelDrawer()

    // when: fitting the container to a size inside an inset
    let hasRoom = drawer.fitTextContainer(size: CGSize(width: 100, height: 40), inset: CGSize(width: 4, height: 2))

    // then: the container takes the size inside the inset, which has room for the text
    expect(hasRoom) == true
    expect(drawer.textContainer.size) == CGSize(width: 92, height: 36)

    // when: fitting it inside an inset as large as the size
    let hasRoomInsideALargeInset = drawer.fitTextContainer(size: CGSize(width: 10, height: 10), inset: CGSize(width: 6, height: 6))

    // then: the container has no room
    expect(hasRoomInsideALargeInset) == false
    expect(drawer.textContainer.size) == .zero
  }

  func test_drawText() throws {
    // given: a drawer with a text
    let drawer = TextLabelDrawer()
    drawer.textStorage.setAttributedString(NSAttributedString(string: "Hello", attributes: [.font: Font.systemFont(ofSize: 15), .foregroundColor: Color.black]))

    // when: drawing it in a size with room
    let pixels = try Self.drawnPixels(width: 100, height: 30) {
      drawer.drawText(size: CGSize(width: 100, height: 30), inset: .zero)
    }

    // then: the text draws
    expect(Self.inkedPixelCount(pixels)) > 0

    // when: drawing it inside an inset as large as the size
    let pixelsWithoutRoom = try Self.drawnPixels(width: 100, height: 30) {
      drawer.drawText(size: CGSize(width: 100, height: 30), inset: CGSize(width: 50, height: 15))
    }

    // then: nothing draws
    expect(Self.inkedPixelCount(pixelsWithoutRoom)) == 0
  }

  #if canImport(AppKit)

  // MARK: - Images

  func test_makeImage_drawsAtTheScaleInTheColorSpace() throws {
    // given: a drawer with a text, and a color space
    let drawer = TextLabelDrawer()
    drawer.textStorage.setAttributedString(NSAttributedString(string: "Hello", attributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.black]))
    let colorSpace = try unwrap(CGColorSpace(name: CGColorSpace.displayP3))
    let appearance = try unwrap(NSAppearance(named: .aqua))

    // when: drawing it into an image at a scale of 2
    let image = try unwrap(drawer.makeImage(size: CGSize(width: 100, height: 20.5), inset: .zero, scale: 2, colorSpace: colorSpace, appearance: appearance))

    // then: the image has the size's pixels, rounded up, in the color space
    expect(image.width) == 200
    expect(image.height) == 41
    expect(image.colorSpace) == colorSpace
  }

  func test_makeImage_sizeWithoutPixels_returnsNil() throws {
    // given: a drawer with a text
    let drawer = TextLabelDrawer()
    drawer.textStorage.setAttributedString(NSAttributedString(string: "Hello"))
    let colorSpace = try unwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let appearance = try unwrap(NSAppearance(named: .aqua))

    // then: an image of a size without pixels is nil
    expect(drawer.makeImage(size: CGSize(width: 0, height: 20), inset: .zero, scale: 2, colorSpace: colorSpace, appearance: appearance)) == nil
    expect(drawer.makeImage(size: CGSize(width: 100, height: 0), inset: .zero, scale: 2, colorSpace: colorSpace, appearance: appearance)) == nil
  }

  func test_scaleShadows_scalesEachShadowsOffsetAndBlur() throws {
    // given: a drawer with a text with two shadows and a part without one
    let drawer = TextLabelDrawer()
    let sharpShadow = NSShadow()
    sharpShadow.shadowOffset = CGSize(width: 2, height: -1)
    sharpShadow.shadowColor = NSColor.red
    let blurredShadow = NSShadow()
    blurredShadow.shadowOffset = CGSize(width: 0, height: 3)
    blurredShadow.shadowBlurRadius = 1.5
    let text = NSMutableAttributedString(string: "Sharp")
    text.addAttribute(.shadow, value: sharpShadow, range: NSRange(location: 0, length: 5))
    text.append(NSAttributedString(string: " plain "))
    text.append(NSAttributedString(string: "blurred", attributes: [.shadow: blurredShadow]))
    drawer.textStorage.setAttributedString(text)

    // when: scaling the shadows by 2
    drawer.scaleShadows(by: 2)

    // then: each shadow's offset and blur are scaled, its color is kept, and the part without a shadow has none
    let scaledSharpShadow = try unwrap(drawer.textStorage.attribute(.shadow, at: 0, effectiveRange: nil) as? NSShadow)
    expect(scaledSharpShadow.shadowOffset) == CGSize(width: 4, height: -2)
    expect(scaledSharpShadow.shadowBlurRadius) == 0
    expect(scaledSharpShadow.shadowColor) == NSColor.red
    let scaledBlurredShadow = try unwrap(drawer.textStorage.attribute(.shadow, at: 12, effectiveRange: nil) as? NSShadow)
    expect(scaledBlurredShadow.shadowOffset) == CGSize(width: 0, height: 6)
    expect(scaledBlurredShadow.shadowBlurRadius) == 3
    expect(drawer.textStorage.attribute(.shadow, at: 7, effectiveRange: nil) == nil) == true
  }

  func test_scaleShadows_textWithoutShadows_leavesTheText() {
    // given: a drawer with a text without shadows, and an observer of the storage's edits
    let drawer = TextLabelDrawer()
    drawer.textStorage.setAttributedString(NSAttributedString(string: "Plain"))
    var editCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: drawer.textStorage, queue: nil) { _ in
      editCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: scaling the shadows
    drawer.scaleShadows(by: 2)

    // then: the storage isn't edited
    expect(editCount) == 0
  }

  #endif

  // MARK: - Helpers

  /// Returns the pixels that a block draws into a bitmap, in flipped coordinates, as a label's drawing does.
  private static func drawnPixels(width: Int, height: Int, draw: () -> Void) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = try unwrap(CGColorSpace(name: CGColorSpace.sRGB))
    try bytes.withUnsafeMutableBytes { buffer in
      let context = try unwrap(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      #if canImport(AppKit)
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
      draw()
      NSGraphicsContext.restoreGraphicsState()
      #endif
      #if canImport(UIKit)
      UIGraphicsPushContext(context)
      draw()
      UIGraphicsPopContext()
      #endif
    }
    return bytes
  }

  /// Returns the number of pixels with any ink.
  private static func inkedPixelCount(_ pixels: [UInt8]) -> Int {
    stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 0 }.count
  }
}
