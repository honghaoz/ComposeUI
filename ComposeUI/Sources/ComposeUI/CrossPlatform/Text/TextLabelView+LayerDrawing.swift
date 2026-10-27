//
//  TextLabelView+LayerDrawing.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/16/26.
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

extension TextLabelView {

  /// Whether the label drawing parity tests verify the running system, which a label draws in a layer on.
  static let isLayerDrawingVerified = isLayerDrawingVerified(onMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)

  /// Returns whether the label drawing parity tests verify a major version of macOS.
  ///
  /// The two drawings can differ on a version that the tests haven't run on, so a label draws in a layer only on a
  /// version that they pass on. To verify a version, on a system of that version:
  /// 1. Run `swift test --filter TextLabelView_LayerDrawingTests` from `ComposeUI/`, which compares AppKit's drawing
  ///    with the layer's on any version.
  /// 2. When the tests pass, add the version here and to the versions that the tests expect this to allow.
  /// 3. Run the tests again, which now also runs the tests that skip on a version that this doesn't allow, and check
  ///    that no test skips, since the tests also skip without a Metal device.
  ///
  /// - Parameter majorVersion: The major version of macOS.
  /// - Returns: Whether the tests verify the version.
  static func isLayerDrawingVerified(onMajorVersion majorVersion: Int) -> Bool {
    majorVersion == 26 || majorVersion == 27
  }

  /// A layer that draws a label's text, into a backing store that Core Animation makes.
  final class DrawingLayer: CALayer {

    /// The label whose text the layer draws.
    weak var labelView: TextLabelView?

    // the layer changes without implicit animations, as the view's own layer does
    override func action(forKey event: String) -> CAAction? {
      nil
    }

    override func display() {
      // the contents that the display replaces go away after the commit, off the main thread, see `ReplacedImageRelease`
      let replacedContents = contents

      // the label shows the image that a worker drew ahead of time for its text, in the pixels that the layer draws,
      // instead of drawing the text
      if let image = labelView?.takeImageToDisplay() {
        contents = image
      } else {
        super.display()
      }

      ReplacedImageRelease.releaseAfterCommit(replacedContents)
    }

    override func draw(in ctx: CGContext) {
      // the appearance's drawing scope is on macOS 11 and later, and a label draws in a layer only on later systems
      guard #available(macOS 11.0, *), let labelView else {
        return
      }

      // the layer's contents aren't flipped, so the context flips for the text, which draws in flipped coordinates, as
      // when AppKit draws the view, and the dynamic colors take the view's appearance, as they do then
      ctx.translateBy(x: 0, y: bounds.height)
      ctx.scaleBy(x: 1, y: -1)
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
      labelView.effectiveAppearance.performAsCurrentDrawingAppearance {
        labelView.drawText()
      }
      NSGraphicsContext.restoreGraphicsState()
    }
  }
}

extension NSAttributedString {

  /// Whether the text draws the same pixels in a label's drawing layer as through AppKit.
  ///
  /// The label drawing parity tests verify each style that this allows.
  var drawsTheSameInALayer: Bool {
    // a label checks each text that it shows in a window, so the styles are read as Core Foundation values, instead of
    // through `enumerateAttributes`, which bridges each run's styles to a Swift dictionary and allocates
    let text = self as CFAttributedString
    let length = CFAttributedStringGetLength(text)
    var drawsTheSame = true
    var location = 0
    while drawsTheSame, location < length {
      var range = CFRange()
      let attributes = CFAttributedStringGetAttributes(text, location, &range)
      withUnsafeMutablePointer(to: &drawsTheSame) { drawsTheSame in
        CFDictionaryApplyFunction(
          attributes,
          { key, value, drawsTheSame in
            guard let key, let value, let drawsTheSame = drawsTheSame?.assumingMemoryBound(to: Bool.self), drawsTheSame.pointee else {
              return
            }
            drawsTheSame.pointee = NSAttributedString.drawsTheSameInALayer(
              key: Unmanaged<CFString>.fromOpaque(key).takeUnretainedValue(),
              value: Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue()
            )
          },
          drawsTheSame
        )
      }
      location = range.location + range.length
    }
    return drawsTheSame
  }

  private static func drawsTheSameInALayer(key: CFString, value: AnyObject) -> Bool {
    switch key {
    case Constants.fontKey:
      guard CFGetTypeID(value) == CTFontGetTypeID() else {
        return false
      }
      return !CTFontGetSymbolicTraits(unsafeDowncast(value, to: CTFont.self)).contains(.traitColorGlyphs)
    case Constants.foregroundColorKey,
         Constants.underlineColorKey:
      // a pattern color draws an image
      guard let color = value as? NSColor else {
        return false
      }
      return color.type != .pattern
    case Constants.paragraphStyleKey:
      // a text block draws borders and a text list draws markers, which the tests don't verify
      guard let style = value as? NSParagraphStyle else {
        return false
      }
      return style.textBlocks.isEmpty && style.textLists.isEmpty
    case Constants.underlineStyleKey:
      guard let style = value as? NSNumber else {
        return false
      }
      return Constants.verifiedUnderlineStyles.contains(style.intValue)
    case Constants.kernKey,
         Constants.trackingKey,
         Constants.baselineOffsetKey,
         Constants.obliquenessKey,
         Constants.expansionKey,
         Constants.ligatureKey,
         Constants.superscriptKey,
         Constants.writingDirectionKey,
         Constants.shadowKey,
         Constants.linkKey:
      return true
    default:
      return false
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The underline styles that the tests verify.
    static let verifiedUnderlineStyles: Set<Int> = [
      NSUnderlineStyle.single.rawValue,
      NSUnderlineStyle.single.union(.patternDot).rawValue,
      NSUnderlineStyle.single.union(.patternDash).rawValue,
      NSUnderlineStyle.single.union(.byWord).rawValue,
    ]

    static let fontKey = NSAttributedString.Key.font.rawValue as CFString
    static let foregroundColorKey = NSAttributedString.Key.foregroundColor.rawValue as CFString
    static let underlineColorKey = NSAttributedString.Key.underlineColor.rawValue as CFString
    static let paragraphStyleKey = NSAttributedString.Key.paragraphStyle.rawValue as CFString
    static let underlineStyleKey = NSAttributedString.Key.underlineStyle.rawValue as CFString
    static let kernKey = NSAttributedString.Key.kern.rawValue as CFString

    /// The tracking key, which `NSAttributedString.Key.tracking` names on macOS 11 and later.
    static let trackingKey = "CTTracking" as CFString

    static let baselineOffsetKey = NSAttributedString.Key.baselineOffset.rawValue as CFString
    static let obliquenessKey = NSAttributedString.Key.obliqueness.rawValue as CFString
    static let expansionKey = NSAttributedString.Key.expansion.rawValue as CFString
    static let ligatureKey = NSAttributedString.Key.ligature.rawValue as CFString
    static let superscriptKey = NSAttributedString.Key.superscript.rawValue as CFString
    static let writingDirectionKey = NSAttributedString.Key.writingDirection.rawValue as CFString
    static let shadowKey = NSAttributedString.Key.shadow.rawValue as CFString
    static let linkKey = NSAttributedString.Key.link.rawValue as CFString
  }
}

#endif
