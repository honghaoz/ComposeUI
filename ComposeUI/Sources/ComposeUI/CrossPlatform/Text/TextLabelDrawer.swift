//
//  TextLabelDrawer.swift
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

/// The TextKit objects that lay out and draw a label's text.
///
/// A `TextLabelView` draws its text with a drawer, and so does each worker that draws labels ahead of time, so that the
/// two lay out and draw a text with objects that are set up the same way. A drawer is used on one thread at a time, as
/// TextKit requires.
final class TextLabelDrawer {

  /// The text that the drawer lays out and draws.
  let textStorage = NSTextStorage()

  /// The layout manager that lays out the text.
  let layoutManager = NSLayoutManager()

  /// The text container that the text lays out in.
  let textContainer = NSTextContainer(size: .zero)

  init() {
    // the storage gets its layout manager before it gets a text, since on UIKit, a storage that gets its text first
    // lays out some complex scripts differently
    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)
    textContainer.lineFragmentPadding = 0

    #if canImport(AppKit)
    // a worker lays out on its own thread, where Apple's guidance for a layout manager requires background layout off,
    // and a label's drawer has no text view that background layout would lay out for, so no drawer uses it
    layoutManager.backgroundLayoutEnabled = false
    #endif
  }

  /// Returns the text that a label shows for a text.
  ///
  /// TextKit 1 aligns a paragraph without a writing direction by the user's language instead of by its text, so each
  /// paragraph is shown in the direction of its text, as ComposeUI measures it.
  ///
  /// - Parameter text: The text that the label is set to show.
  /// - Returns: The text that the label shows.
  static func shownText(of text: NSAttributedString) -> NSAttributedString {
    text.resolvingNaturalWritingDirections()
  }

  /// The maximum number of lines that the text lays out in, 0 for no limit.
  ///
  /// A negative number has no limit either.
  var numberOfLines: Int {
    get {
      textContainer.maximumNumberOfLines
    }
    set {
      // a change lays the text out again, so an unchanged value isn't set
      let maximumNumberOfLines = max(newValue, 0)
      if textContainer.maximumNumberOfLines != maximumNumberOfLines {
        textContainer.maximumNumberOfLines = maximumNumberOfLines
      }
    }
  }

  /// The line break mode of the text's last line.
  var lineBreakMode: NSLineBreakMode {
    get {
      textContainer.lineBreakMode
    }
    set {
      // a change lays the text out again, so an unchanged value isn't set
      if textContainer.lineBreakMode != newValue {
        textContainer.lineBreakMode = newValue
      }
    }
  }

  /// Gives the drawer a label's text, settings and size, which lays out the text once.
  ///
  /// A UIKit layout manager lays out its text as soon as the text or the text container changes, instead of when the
  /// text is drawn, so when both change, the old text leaves before the container changes, and the new text comes
  /// after, instead of laying out the old text in the new container and the new text in the old one.
  ///
  /// - Parameters:
  ///   - text: The text to lay out, or `nil` to keep the drawer's text.
  ///   - numberOfLines: The maximum number of lines that the text lays out in, 0 for no limit.
  ///   - lineBreakMode: The line break mode of the text's last line.
  ///   - size: The size that the text lays out in, with the inset.
  ///   - inset: The inset of the text, the width from the left and right edges and the height from the top and bottom.
  /// - Returns: Whether the container has room to show the text.
  func update(text: NSAttributedString?, numberOfLines: Int, lineBreakMode: NSLineBreakMode, size: CGSize, inset: CGSize) -> Bool {
    if text != nil,
       textStorage.length > 0,
       textContainer.size != Self.containerSize(size: size, inset: inset) || self.numberOfLines != max(numberOfLines, 0) || self.lineBreakMode != lineBreakMode
    {
      textStorage.setAttributedString(NSAttributedString())
    }

    self.numberOfLines = numberOfLines
    self.lineBreakMode = lineBreakMode
    let hasRoom = fitTextContainer(size: size, inset: inset)
    if let text {
      textStorage.setAttributedString(text)
    }
    return hasRoom
  }

  /// Sizes the text container to a size inside an inset, where the text lays out.
  ///
  /// - Parameters:
  ///   - size: The size that the text lays out in, with the inset.
  ///   - inset: The inset of the text, the width from the left and right edges and the height from the top and bottom.
  /// - Returns: Whether the container has room to show the text.
  func fitTextContainer(size: CGSize, inset: CGSize) -> Bool {
    let containerSize = Self.containerSize(size: size, inset: inset)

    // the container is resized only when its size changes, since a resize lays the text out again
    if textContainer.size != containerSize {
      textContainer.size = containerSize
    }

    // a text container without room still lays out a glyph, which an inset as large as the size leaves no room to show
    return containerSize.width > 0 && containerSize.height > 0
  }

  /// Returns the size of the text container that fits a size inside an inset.
  ///
  /// - Parameters:
  ///   - size: The size that the text lays out in, with the inset.
  ///   - inset: The inset of the text, the width from the left and right edges and the height from the top and bottom.
  /// - Returns: The size of the text container.
  private static func containerSize(size: CGSize, inset: CGSize) -> CGSize {
    CGSize(width: max(0, size.width - inset.width * 2), height: max(0, size.height - inset.height * 2))
  }

  /// Draws the text in the current graphics context, laid out in a size inside an inset.
  ///
  /// - Parameters:
  ///   - size: The size that the text lays out in, with the inset.
  ///   - inset: The inset of the text, the width from the left and right edges and the height from the top and bottom.
  func drawText(size: CGSize, inset: CGSize) {
    guard fitTextContainer(size: size, inset: inset) else {
      return
    }

    let glyphRange = layoutManager.glyphRange(for: textContainer)
    let origin = CGPoint(x: inset.width, y: inset.height)
    layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
    layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
  }
}

#if canImport(AppKit)

// MARK: - Images

extension TextLabelDrawer {

  /// Draws the text into an image, in the pixels that a label's drawing layer draws for it in a window.
  ///
  /// Core Animation draws the drawing layer's backing store in the window's color space, with the window's scale in the
  /// backing store's base space, so the image is drawn in the window's color space, and the text's shadows are scaled
  /// first, see `scaleShadows(by:)`, since the image's scale is in its context's transform instead.
  ///
  /// - Parameters:
  ///   - size: The label's size.
  ///   - inset: The label's text container inset.
  ///   - scale: The scale of the window's backing store.
  ///   - colorSpace: The window's color space.
  ///   - appearance: The label's appearance, which resolves the text's dynamic colors.
  /// - Returns: The image, `nil` for a size without pixels.
  func makeImage(size: CGSize, inset: CGSize, scale: CGFloat, colorSpace: CGColorSpace, appearance: NSAppearance) -> CGImage? {
    let width = Int((size.width * scale).rounded(.up))
    let height = Int((size.height * scale).rounded(.up))
    // the appearance's drawing scope is on macOS 11 and later, and a label draws in a layer only on later systems
    guard #available(macOS 11.0, *),
          width > 0,
          height > 0,
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
          )
    else {
      return nil
    }

    // an image's contents aren't flipped, so the context flips for the text, which draws in flipped coordinates, as the
    // drawing layer's context does
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    appearance.performAsCurrentDrawingAppearance {
      drawText(size: size, inset: inset)
    }
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()
  }

  /// Scales the shadows of the text by a scale, for drawing it into an image, see `makeImage(size:inset:scale:colorSpace:appearance:)`.
  ///
  /// Core Graphics places a shadow in its context's base space, which a backing store scales and an image doesn't, so
  /// the offsets and the blurs of the image's shadows are scaled to match the backing store's.
  ///
  /// - Parameter scale: The scale of the window's backing store.
  func scaleShadows(by scale: CGFloat) {
    var shadows: [(range: NSRange, shadow: NSShadow)] = []
    textStorage.enumerateAttribute(.shadow, in: NSRange(location: 0, length: textStorage.length)) { value, range, _ in
      if let shadow = value as? NSShadow {
        shadows.append((range, shadow))
      }
    }
    guard !shadows.isEmpty else {
      return
    }

    textStorage.beginEditing()
    for (range, shadow) in shadows {
      let scaledShadow = NSShadow()
      scaledShadow.shadowOffset = CGSize(width: shadow.shadowOffset.width * scale, height: shadow.shadowOffset.height * scale)
      scaledShadow.shadowBlurRadius = shadow.shadowBlurRadius * scale
      scaledShadow.shadowColor = shadow.shadowColor
      textStorage.addAttribute(.shadow, value: scaledShadow, range: range)
    }
    textStorage.endEditing()
  }
}

#endif
