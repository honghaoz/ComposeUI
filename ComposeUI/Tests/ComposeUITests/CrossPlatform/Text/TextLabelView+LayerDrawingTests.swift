//
//  TextLabelView+LayerDrawingTests.swift
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

import ChouTiTest

@testable import ComposeUI

/// The label drawing parity tests: a label draws a text in its drawing layer only where the layer draws the same pixels
/// as AppKit, which these tests check, through what Core Animation shows, on each system they run on.
class TextLabelView_LayerDrawingTests: XCTestCase {

  // MARK: - Parity

  func test_verifiedStyles_drawInTheLayer_inTheSamePixelsAsAppKit() throws {
    // a Retina screen and a screen of a scale of 1, which rasterize the glyphs differently
    for scale: CGFloat in [2, 1] {
      for testCase in Self.verifiedCases() {
        let name = "\(testCase.name) at \(scale)x"

        // given: a label in a window, showing a text whose styles the label draws in its layer
        let (renderer, labelView) = try Self.makeLabel(testCase, scale: scale)

        // then: the label draws the text in its layer, on the systems that the tests verify
        expect(labelView.test.drawsInLayer, name) == TextLabelView.isLayerDrawingVerified

        // when: drawing it through AppKit, and in the layer
        labelView.test.forcedDrawsInLayer = false
        let appKitPixels = try renderer.render()
        labelView.test.forcedDrawsInLayer = true
        let layerPixels = try renderer.render()

        // then: the layer draws the same pixels as AppKit
        expect(appKitPixels.differingPixelCount(from: layerPixels), name) == 0
        if testCase.text.string.contains(where: { !$0.isWhitespace }) {
          expect(appKitPixels.inkedPixelCount, name) > 0
        }
      }
    }
  }

  func test_unverifiedStyles_drawThroughAppKit() throws {
    for testCase in Self.unverifiedCases() {
      // given: a label in a window, showing a text with a style that the tests don't verify in the layer
      let (renderer, labelView) = try Self.makeLabel(testCase)

      // then: AppKit draws the text, with the drawing layer hidden, if the label has one
      expect(labelView.test.drawsInLayer, testCase.name) == false
      expect(labelView.wantsUpdateLayer, testCase.name) == false
      expect(labelView.test.drawingLayer?.isHidden ?? true, testCase.name) == true
      expect(try renderer.render().inkedPixelCount, testCase.name) > 0
    }
  }

  func test_sizeBetweenPixels_drawsThroughAppKit() throws {
    // given: a label in a window, showing a text in a size between pixels
    let testCase = Case(name: "plain", text: Self.text("Row 12 title"))
    let (renderer, labelView) = try Self.makeLabel(testCase, size: CGSize(width: 120.5, height: 20.25))

    // then: AppKit draws the text, which a layer draws in other pixels at a size between pixels
    expect(labelView.test.drawsInLayer) == false

    // when: resizing it to whole pixels
    labelView.setFrameSize(CGSize(width: 120, height: 20))

    // then: the label draws in its layer, on the systems that the tests verify, in the same pixels as AppKit
    expect(labelView.test.drawsInLayer) == TextLabelView.isLayerDrawingVerified
    let pixels = try renderer.render()
    labelView.test.forcedDrawsInLayer = false
    expect(try renderer.render().differingPixelCount(from: pixels)) == 0
  }

  // MARK: - Drawing Mode

  func test_outOfAWindow_drawsThroughAppKit_untilInAWindow() throws {
    // given: a label out of a window, showing a text whose styles the label draws in its layer
    let renderer = try WindowRenderer(size: CGSize(width: 200, height: 30))
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
    labelView.attributedString = Self.text("Row 12 title")

    // then: AppKit draws it, without a window's scale to check the size in, as the label chooses without a test forcing
    // it
    expect(labelView.test.drawsInLayer) == false
    expect(labelView.test.drawingLayer) == nil
    expect(labelView.test.forcedDrawsInLayer) == nil

    // when: adding it to a window
    renderer.view.addSubview(labelView)

    // then: the label draws in its layer, on the systems that the tests verify, at the window's scale
    expect(labelView.test.drawsInLayer) == TextLabelView.isLayerDrawingVerified
    if TextLabelView.isLayerDrawingVerified {
      expect(labelView.test.drawingLayer?.contentsScale) == renderer.window.backingScaleFactor
      expect(labelView.test.drawingLayer?.superlayer) === labelView.layer
    }

    // when: removing it from the window, as a reused label leaves its window
    labelView.removeFromSuperview()

    // then: it keeps drawing in its layer, which saves switching back when it's reused
    expect(labelView.test.drawsInLayer) == TextLabelView.isLayerDrawingVerified
  }

  func test_textChange_switchesBetweenTheLayerAndAppKit_inTheSamePixelsAsAppKit() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a window, drawing a text in its layer
    let (renderer, labelView) = try Self.makeLabel(Case(name: "plain", text: Self.text("Row 12 title")))
    expect(labelView.test.drawsInLayer) == true
    expect(try Self.differingPixelCountFromAppKit(labelView, renderer)) == 0

    // when: showing a text with an emoji, which AppKit draws
    labelView.attributedString = Self.text("Party 🎉")

    // then: AppKit draws it, and the drawing layer hides and lets its drawing go
    expect(labelView.test.drawsInLayer) == false
    expect(labelView.test.drawingLayer?.isHidden) == true
    expect(labelView.test.drawingLayer?.contents) == nil
    expect(try renderer.render().inkedPixelCount) > 0

    // when: showing a text without an emoji again
    labelView.attributedString = Self.text("Row 13 title")

    // then: the label draws in its layer again, in the same pixels as AppKit, without what AppKit drew before
    expect(labelView.test.drawsInLayer) == true
    expect(labelView.test.drawingLayer?.isHidden) == false
    expect(try Self.differingPixelCountFromAppKit(labelView, renderer)) == 0
  }

  func test_resize_drawsInTheNewSize_inTheSamePixelsAsAppKit() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a window, drawing a text that wraps in its layer
    let text = Self.text("A paragraph that wraps across several lines in the label.")
    let (renderer, labelView) = try Self.makeLabel(Case(name: "wrapped", text: text, lines: 0, lineBreakMode: .byWordWrapping))
    _ = try renderer.render()

    // when: resizing it, which wraps the text again
    labelView.setFrameSize(CGSize(width: 120, height: 64))

    // then: the drawing layer takes the new size, and draws the text in the same pixels as AppKit
    expect(labelView.test.drawingLayer?.frame) == labelView.bounds
    expect(try Self.differingPixelCountFromAppKit(labelView, renderer)) == 0
  }

  func test_settingsChange_drawsAgain_inTheSamePixelsAsAppKit() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a window, drawing a text in its layer
    let text = Self.text("A paragraph that wraps across several lines in the label.")
    let (renderer, labelView) = try Self.makeLabel(Case(name: "wrapped", text: text, lines: 0, lineBreakMode: .byWordWrapping))
    _ = try renderer.render()

    // when: changing the number of lines, the line break mode and the inset
    labelView.numberOfLines = 2
    labelView.lineBreakMode = .byTruncatingTail
    labelView.textContainerInset = CGSize(width: 4, height: 2)

    // then: the layer draws the text again, in the same pixels as AppKit
    expect(labelView.test.drawsInLayer) == true
    expect(try Self.differingPixelCountFromAppKit(labelView, renderer)) == 0
  }

  func test_appearanceChange_drawsTheDynamicColorsOfTheNewAppearance() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a window in the light appearance, drawing a text in the label color in its layer
    let text = Self.text("Label color", [.foregroundColor: NSColor.labelColor, .font: NSFont.systemFont(ofSize: 20)])
    let (renderer, labelView) = try Self.makeLabel(Case(name: "label color", text: text))
    let lightPixels = try renderer.render()

    // when: the window changes to the dark appearance
    renderer.window.appearance = NSAppearance(named: .darkAqua)

    // then: the layer draws the text in the dark appearance's label color, in the same pixels as AppKit
    expect(labelView.test.drawsInLayer) == true
    let darkPixels = try renderer.render()
    expect(darkPixels.differingPixelCount(from: lightPixels)) > 0
    expect(try Self.differingPixelCountFromAppKit(labelView, renderer)) == 0
  }

  func test_displayRequest_drawsTheTextAgain_inTheSamePixelsAsAppKit() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a window, drawing a text in its layer, in a color that changes without a new appearance, as a
    // system color does when the user picks another one
    var systemColor = NSColor.systemRed
    let color = NSColor(name: nil) { _ in systemColor }
    let (renderer, labelView) = try Self.makeLabel(Case(name: "system color", text: Self.text("System colored text", [.foregroundColor: color])))
    let redPixels = try renderer.render()
    expect(labelView.test.drawsInLayer) == true

    // when: the color changes, which AppKit answers by displaying the views again
    systemColor = .systemBlue
    labelView.needsDisplay = true

    // then: the layer draws the text in the new color, in the same pixels as AppKit
    let pixels = try renderer.render()
    expect(pixels.differingPixelCount(from: redPixels)) > 0
    expect(try Self.appKitPixels(labelView, renderer).differingPixelCount(from: pixels)) == 0
  }

  func test_changedCoordinates_drawThroughAppKit_untilChangedBack() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // the changes of the label's coordinates, or of an ancestor's, that AppKit draws into the view's drawing, with the
    // changes that put them back exactly
    typealias Change = (TextLabelView, NSView) -> Void
    let changes: [(name: String, change: Change, undo: Change?)] = [
      ("bounds origin", { label, _ in label.setBoundsOrigin(NSPoint(x: 10, y: 0)) }, { label, _ in label.setBoundsOrigin(.zero) }),
      ("translated origin", { label, _ in label.translateOrigin(to: NSPoint(x: 3, y: 0)) }, { label, _ in label.translateOrigin(to: NSPoint(x: -3, y: 0)) }),
      ("bounds origin across a resize", { label, _ in
        label.setBoundsOrigin(NSPoint(x: 10, y: 0))
        label.setFrameSize(NSSize(width: 190, height: 64))
      }, { label, _ in label.setBoundsOrigin(.zero) }),
      ("bounds size", { label, _ in label.setBoundsSize(NSSize(width: 100, height: 32)) }, { label, _ in label.setBoundsSize(label.frame.size) }),
      ("unit square", { label, _ in label.scaleUnitSquare(to: NSSize(width: 2, height: 2)) }, { label, _ in label.scaleUnitSquare(to: NSSize(width: 0.5, height: 0.5)) }),
      ("unit square across a resize", { label, _ in
        label.scaleUnitSquare(to: NSSize(width: 2, height: 2))
        label.setFrameSize(NSSize(width: 190, height: 64))
      }, { label, _ in label.scaleUnitSquare(to: NSSize(width: 0.5, height: 0.5)) }),
      ("bounds rotation", { label, _ in label.rotate(byDegrees: 5) }, nil),
      ("frame rotation", { label, _ in label.frameRotation = 5 }, nil),
      ("ancestor's unit square", { _, ancestor in ancestor.scaleUnitSquare(to: NSSize(width: 2, height: 2)) }, { _, ancestor in ancestor.scaleUnitSquare(to: NSSize(width: 0.5, height: 0.5)) }),
      ("ancestor's rotation", { _, ancestor in ancestor.rotate(byDegrees: 5) }, nil),
    ]
    for (name, change, undo) in changes {
      // given: a label away from the edges of a view in a window, which shows any drawing past the label's bounds,
      // drawing a text in its layer that's wider than half the label, which a drawing layer left at a scaled size cuts
      let renderer = try WindowRenderer(size: CGSize(width: 240, height: 64))
      let ancestor = NSView(frame: renderer.view.bounds)
      renderer.view.addSubview(ancestor)
      let labelView = TextLabelView(frame: CGRect(x: 20, y: 0, width: 200, height: 64))
      labelView.attributedString = Self.text("Row 12 title in the label")
      ancestor.addSubview(labelView)
      _ = try renderer.render()
      expect(labelView.test.drawsInLayer, name) == true

      // when: changing the coordinates
      change(labelView, ancestor)

      // then: AppKit draws the text from the next drawing on
      let shownPixels = try renderer.render()
      expect(labelView.test.drawsInLayer, name) == false
      expect(try Self.appKitPixels(labelView, renderer).differingPixelCount(from: shownPixels), name) == 0

      guard let undo else {
        continue
      }

      // when: changing them back
      undo(labelView, ancestor)

      // then: the label draws in its layer again, in the same pixels as AppKit
      let pixelsAfterUndo = try renderer.render()
      expect(labelView.test.drawsInLayer, name) == true
      expect(try Self.appKitPixels(labelView, renderer).differingPixelCount(from: pixelsAfterUndo), name) == 0
    }
  }

  func test_magnification_drawsThroughAppKit_untilMagnifiedBack() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a scroll view in a window, drawing a text in its layer
    let renderer = try WindowRenderer(size: CGSize(width: 200, height: 64))
    let scrollView = NSScrollView(frame: renderer.view.bounds)
    scrollView.allowsMagnification = true
    scrollView.maxMagnification = 4
    scrollView.documentView = NSView(frame: renderer.view.bounds)
    renderer.view.addSubview(scrollView)
    let labelView = TextLabelView(frame: CGRect(x: 0, y: 0, width: 200, height: 64))
    labelView.attributedString = Self.text("Row 12 title")
    scrollView.documentView?.addSubview(labelView)
    _ = try renderer.render()
    expect(labelView.test.drawsInLayer) == true

    // when: the scroll view magnifies its content, which AppKit draws at the magnified scale
    scrollView.magnification = 2

    // then: AppKit draws the text from the next drawing on
    let magnifiedPixels = try renderer.render()
    expect(labelView.test.drawsInLayer) == false
    expect(try Self.appKitPixels(labelView, renderer).differingPixelCount(from: magnifiedPixels)) == 0

    // when: the scroll view stops magnifying
    scrollView.magnification = 1

    // then: the label draws in its layer again, in the same pixels as AppKit
    let pixels = try renderer.render()
    expect(labelView.test.drawsInLayer) == true
    expect(try Self.appKitPixels(labelView, renderer).differingPixelCount(from: pixels)) == 0
  }

  func test_backingScaleChange_drawsAtTheNewScale() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a window on a Retina screen, drawing a text in its layer
    let (renderer, labelView) = try Self.makeLabel(Case(name: "plain", text: Self.text("Row 12 title")), size: CGSize(width: 120, height: 20))
    let retinaPixels = try renderer.render()
    expect(labelView.test.drawsInLayer) == true
    expect(labelView.test.drawingLayer?.contentsScale) == 2

    // when: the window moves to a screen of a scale of 1, which AppKit tells the label of
    renderer.window.scale = 1
    labelView.viewDidChangeBackingProperties()

    // then: the layer draws the text again at the new scale, in the same pixels as AppKit, in half as many pixels
    // across as on the Retina screen
    expect(labelView.test.drawsInLayer) == true
    expect(labelView.test.drawingLayer?.contentsScale) == 1
    expect(labelView.test.drawingLayer?.needsDisplay()) == true
    let pixels = try renderer.render()
    expect(pixels.width) == retinaPixels.width / 2
    expect(pixels.differingPixelCount(from: retinaPixels)) == Int.max
    expect(try Self.differingPixelCountFromAppKit(labelView, renderer)) == 0

    // when: resizing it to a size that's in whole pixels at a scale of 2, but between pixels at a scale of 1
    labelView.setFrameSize(CGSize(width: 120.5, height: 20))

    // then: AppKit draws the text
    expect(labelView.test.drawsInLayer) == false
  }

  func test_resizeAnimation_drawsAsAppKitDoes() throws {
    // given: labels that grow, shrink, and get taller as their text wraps, through an animation
    let text = Self.text("A label that changes its size as it animates", [.font: NSFont.systemFont(ofSize: 13)])
    let sizes: [(name: String, from: CGSize, to: CGSize)] = [
      ("grow", CGSize(width: 120, height: 36), CGSize(width: 240, height: 36)),
      ("shrink", CGSize(width: 240, height: 36), CGSize(width: 120, height: 36)),
      ("wrap", CGSize(width: 240, height: 18), CGSize(width: 110, height: 36)),
    ]
    for size in sizes {
      var pixels: [Bool: [RenderedPixels]] = [:]
      for drawsInLayer in [false, true] {
        let renderer = try WindowRenderer(size: CGSize(width: 250, height: 40))
        let labelView = TextLabelView(frame: CGRect(origin: .zero, size: size.from))
        labelView.numberOfLines = 0
        labelView.attributedString = text
        renderer.view.addSubview(labelView)
        labelView.test.forcedDrawsInLayer = drawsInLayer
        _ = try renderer.render()

        // when: the frame changes, and the layer animates from the old size, as in an animated refresh
        let oldBounds = try XCTUnwrap(labelView.layer?.bounds)
        let oldPosition = try XCTUnwrap(labelView.layer?.position)
        labelView.setFrameSize(size.to)
        let begin = CACurrentMediaTime() + 10
        for (keyPath, value) in [("bounds", NSValue(rect: oldBounds)), ("position", NSValue(point: oldPosition))] {
          let animation = CABasicAnimation(keyPath: keyPath)
          animation.fromValue = value
          animation.duration = 1
          animation.beginTime = begin
          animation.fillMode = .both
          labelView.layer?.add(animation, forKey: keyPath)
        }
        pixels[drawsInLayer] = try [0, 0.5, 1].map { try renderer.render(at: begin + $0) }
      }

      // then: the layer shows the same pixels as AppKit's drawing at the start, halfway, and at the end
      let appKitPixels = try XCTUnwrap(pixels[false])
      let layerPixels = try XCTUnwrap(pixels[true])
      for (index, progress) in ["start", "halfway", "end"].enumerated() {
        expect(appKitPixels[index].differingPixelCount(from: layerPixels[index]), "\(size.name) \(progress)") == 0
      }
    }
  }

  // MARK: - Drawing Layer

  func test_drawingLayer_changesWithoutImplicitAnimations() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a window, drawing a text in its layer
    let (renderer, labelView) = try Self.makeLabel(Case(name: "plain", text: Self.text("Row 12 title")))
    _ = try renderer.render()
    let drawingLayer = try XCTUnwrap(labelView.test.drawingLayer)

    // when: changing its text and size in a transaction with implicit animations
    CATransaction.begin()
    labelView.attributedString = Self.text("Row 13 title")
    labelView.setFrameSize(CGSize(width: 180, height: 30))
    CATransaction.commit()

    // then: the drawing layer changes without animations
    expect(drawingLayer.animationKeys()) == nil
    expect(drawingLayer.action(forKey: "contents") == nil) == true
  }

  func test_drawingLayer_drawsBelowTheLabelsSublayers_inTheSamePixelsAsAppKit() throws {
    try XCTSkipUnless(TextLabelView.isLayerDrawingVerified, "a label draws in a layer only on the systems that the tests verify")

    // given: a label in a window, drawing a text with an emoji through AppKit, with an opaque sublayer over part of it
    let (renderer, labelView) = try Self.makeLabel(Case(name: "emoji", text: Self.text("Party \u{1F389}")))
    let overlay = CALayer()
    overlay.backgroundColor = NSColor.red.cgColor
    overlay.frame = CGRect(x: 0, y: 0, width: 40, height: 64)
    labelView.layer?.addSublayer(overlay)
    expect(labelView.test.drawsInLayer) == false

    // when: showing a text that the label draws in its layer
    labelView.attributedString = Self.text("Row 12 title")

    // then: the drawing layer goes below the sublayer, which covers the text as it covers AppKit's drawing
    expect(labelView.test.drawsInLayer) == true
    expect(labelView.layer?.sublayers?.first) === labelView.test.drawingLayer
    expect(try Self.differingPixelCountFromAppKit(labelView, renderer)) == 0
  }

  func test_drawingLayer_withoutALabel_drawsNothing() {
    // given: a drawing layer without a label
    let drawingLayer = TextLabelView.DrawingLayer()
    drawingLayer.frame = CGRect(x: 0, y: 0, width: 20, height: 10)

    // then: drawing it draws nothing, and doesn't crash
    drawingLayer.display()
    expect(drawingLayer.labelView) == nil
  }

  // MARK: - Verified Styles

  func test_drawsTheSameInALayer_checksEachStyle() {
    let font = NSFont.systemFont(ofSize: 15)

    // then: a text with the verified styles draws the same in a layer
    expect(NSAttributedString(string: "").drawsTheSameInALayer) == true
    expect(NSAttributedString(string: "Plain", attributes: [.font: font, .foregroundColor: NSColor.labelColor]).drawsTheSameInALayer) == true
    expect(NSAttributedString(string: "Underline", attributes: [.underlineStyle: NSUnderlineStyle.single.union(.byWord).rawValue, .underlineColor: NSColor.red]).drawsTheSameInALayer) == true

    // then: a font with color glyphs, a pattern color, a text block, a text list, an unverified underline and an
    // unverified style keep AppKit's drawing
    expect(NSAttributedString(string: "Emoji", attributes: [.font: NSFont(name: "Apple Color Emoji", size: 15) ?? font]).drawsTheSameInALayer) == false
    let pattern = NSColor(patternImage: NSImage(size: NSSize(width: 2, height: 2)))
    expect(NSAttributedString(string: "Pattern", attributes: [.foregroundColor: pattern]).drawsTheSameInALayer) == false
    let blockStyle = NSMutableParagraphStyle()
    blockStyle.textBlocks = [NSTextBlock()]
    expect(NSAttributedString(string: "Block", attributes: [.paragraphStyle: blockStyle]).drawsTheSameInALayer) == false
    let listStyle = NSMutableParagraphStyle()
    listStyle.textLists = [NSTextList(markerFormat: .disc, options: 0)]
    expect(NSAttributedString(string: "List", attributes: [.paragraphStyle: listStyle]).drawsTheSameInALayer) == false
    expect(NSAttributedString(string: "Thick", attributes: [.underlineStyle: NSUnderlineStyle.thick.rawValue]).drawsTheSameInALayer) == false
    expect(NSAttributedString(string: "Custom", attributes: [NSAttributedString.Key("com.example.custom"): true]).drawsTheSameInALayer) == false

    // then: a style of an unexpected type keeps AppKit's drawing
    expect(NSAttributedString(string: "Font", attributes: [.font: "Helvetica"]).drawsTheSameInALayer) == false
    expect(NSAttributedString(string: "Color", attributes: [.foregroundColor: "red"]).drawsTheSameInALayer) == false
    expect(NSAttributedString(string: "Style", attributes: [.paragraphStyle: "centered"]).drawsTheSameInALayer) == false
    expect(NSAttributedString(string: "Underline", attributes: [.underlineStyle: "single"]).drawsTheSameInALayer) == false
  }

  func test_isLayerDrawingVerified_onlyOnTheSystemsThatTheTestsVerify() {
    // then: a label draws in a layer on macOS 26, which the tests verify, and keeps AppKit's drawing on an earlier or a
    // later system, until the tests pass on it
    expect(TextLabelView.isLayerDrawingVerified(onMajorVersion: 26)) == true
    expect(TextLabelView.isLayerDrawingVerified(onMajorVersion: 15)) == false
    expect(TextLabelView.isLayerDrawingVerified(onMajorVersion: 27)) == false

    // then: the running system's major version decides
    let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    expect(TextLabelView.isLayerDrawingVerified) == TextLabelView.isLayerDrawingVerified(onMajorVersion: majorVersion)
  }

  // MARK: - Helpers

  private struct Case {

    let name: String
    let text: NSAttributedString
    let lines: Int
    let lineBreakMode: NSLineBreakMode
    let inset: CGSize

    init(name: String, text: NSAttributedString, lines: Int = 1, lineBreakMode: NSLineBreakMode = .byTruncatingTail, inset: CGSize = .zero) {
      self.name = name
      self.text = text
      self.lines = lines
      self.lineBreakMode = lineBreakMode
      self.inset = inset
    }
  }

  private static func makeLabel(_ testCase: Case, size: CGSize = CGSize(width: 200, height: 64), scale: CGFloat = 2) throws -> (WindowRenderer, TextLabelView) {
    let renderer = try WindowRenderer(size: size, scale: scale)
    let labelView = TextLabelView(frame: CGRect(origin: .zero, size: size))
    labelView.numberOfLines = testCase.lines
    labelView.lineBreakMode = testCase.lineBreakMode
    labelView.textContainerInset = testCase.inset
    labelView.attributedString = testCase.text
    renderer.view.addSubview(labelView)
    return (renderer, labelView)
  }

  /// Returns the number of pixels that differ between what the label shows and what AppKit draws for it.
  private static func differingPixelCountFromAppKit(_ labelView: TextLabelView, _ renderer: WindowRenderer) throws -> Int {
    let pixels = try renderer.render()
    return try appKitPixels(labelView, renderer).differingPixelCount(from: pixels)
  }

  /// Returns the pixels that AppKit draws for the label, which the test forces, before letting the label choose again.
  private static func appKitPixels(_ labelView: TextLabelView, _ renderer: WindowRenderer) throws -> RenderedPixels {
    labelView.test.forcedDrawsInLayer = false
    defer {
      labelView.test.forcedDrawsInLayer = nil
    }
    return try renderer.render()
  }

  private static func text(_ string: String, _ attributes: [NSAttributedString.Key: Any] = [:]) -> NSAttributedString {
    var allAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.black]
    allAttributes.merge(attributes) { $1 }
    return NSAttributedString(string: string, attributes: allAttributes)
  }

  private static func paragraphStyle(_ configure: (NSMutableParagraphStyle) -> Void) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    configure(style)
    return style
  }

  private static func shadow(offset: CGSize, blur: CGFloat, color: NSColor) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowOffset = offset
    shadow.shadowBlurRadius = blur
    shadow.shadowColor = color
    return shadow
  }

  /// The texts whose styles a label draws in its layer, which cover each verified style.
  private static func verifiedCases() -> [Case] {
    let paragraph = "A paragraph that wraps across several lines in the label."
    let wrap = NSLineBreakMode.byWordWrapping
    let link = NSMutableAttributedString(attributedString: text("Visit the link here"))
    link.addAttribute(.link, value: "https://example.com", range: NSRange(location: 10, length: 4))
    var cases = [
      // fonts and sizes
      Case(name: "system 13", text: text("Row 12 title", [.font: NSFont.systemFont(ofSize: 13)])),
      Case(name: "system 13 semibold", text: text("Row 12 title", [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)])),
      Case(name: "system 9", text: text("Tiny system text at nine points", [.font: NSFont.systemFont(ofSize: 9)])),
      Case(name: "system 36 light", text: text("Light", [.font: NSFont.systemFont(ofSize: 36, weight: .light)])),
      Case(name: "helvetica 14", text: text("Helvetica text", [.font: NSFont(name: "Helvetica", size: 14) ?? NSFont.systemFont(ofSize: 14)])),
      Case(name: "times 16 italic", text: text("Times italic", [.font: NSFontManager.shared.convert(NSFont(name: "Times New Roman", size: 16) ?? NSFont.systemFont(ofSize: 16), toHaveTrait: .italicFontMask)])),
      Case(name: "menlo 12", text: text("let x = 42 // code", [.font: NSFont(name: "Menlo", size: 12) ?? NSFont.systemFont(ofSize: 12)])),
      Case(name: "monospaced digits", text: text("1234567890", [.font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)])),
      Case(name: "no attributes", text: NSAttributedString(string: "Plain text without attributes"), lines: 0, lineBreakMode: wrap),
      // scripts, which the text storage gives substitute fonts
      Case(name: "chinese", text: text("中文文本的标签显示")),
      Case(name: "japanese", text: text("日本語のテキスト表示")),
      Case(name: "korean", text: text("한국어 텍스트 표시")),
      Case(name: "thai", text: text("ข้อความภาษาไทย")),
      Case(name: "devanagari", text: text("हिन्दी पाठ प्रदर्शन")),
      Case(name: "hebrew", text: text("טקסט בעברית")),
      Case(name: "arabic", text: text("مرحبا بالعالم، هذا نص عربي"), lines: 0, lineBreakMode: wrap),
      Case(name: "mixed directions", text: text("Hello مرحبا world")),
      Case(name: "combining marks", text: text("Cafe\u{301} nin\u{303}o u\u{308}ber")),
      Case(name: "symbols", text: text("→ ✓ © ® ° ±")),
      // colors
      Case(name: "label color", text: text("Label color", [.foregroundColor: NSColor.labelColor])),
      Case(name: "secondary label color", text: text("Secondary label color", [.foregroundColor: NSColor.secondaryLabelColor])),
      Case(name: "system blue", text: text("System blue", [.foregroundColor: NSColor.systemBlue])),
      Case(name: "translucent", text: text("Half black", [.foregroundColor: NSColor.black.withAlphaComponent(0.5)])),
      Case(name: "display p3", text: text("Display P3 red", [.foregroundColor: NSColor(displayP3Red: 1, green: 0.1, blue: 0.1, alpha: 1)])),
      // paragraph styles
      Case(name: "right aligned", text: text("Right aligned", [.paragraphStyle: paragraphStyle { $0.alignment = .right }])),
      Case(name: "centered", text: text("Centered", [.paragraphStyle: paragraphStyle { $0.alignment = .center }])),
      Case(name: "justified", text: text(paragraph, [.paragraphStyle: paragraphStyle { $0.alignment = .justified }]), lines: 0, lineBreakMode: wrap),
      Case(name: "line spacing", text: text(paragraph, [.paragraphStyle: paragraphStyle { $0.lineSpacing = 6 }]), lines: 0, lineBreakMode: wrap),
      Case(name: "line height multiple", text: text(paragraph, [.paragraphStyle: paragraphStyle { $0.lineHeightMultiple = 1.4 }]), lines: 0, lineBreakMode: wrap),
      Case(name: "indents", text: text(paragraph, [.paragraphStyle: paragraphStyle { $0.firstLineHeadIndent = 12
        $0.headIndent = 6
        $0.tailIndent = -6
      }]), lines: 0, lineBreakMode: wrap),
      Case(name: "paragraph spacing", text: text("First paragraph\nSecond paragraph", [.paragraphStyle: paragraphStyle { $0.paragraphSpacing = 8 }]), lines: 0, lineBreakMode: wrap),
      Case(name: "tabs", text: text("a\tb\tc\td")),
      Case(name: "hyphenation", text: text("Antidisestablishmentarianism extraordinarily", [.paragraphStyle: paragraphStyle { $0.hyphenationFactor = 1 }]), lines: 0, lineBreakMode: wrap),
      // line breaks and insets
      Case(name: "truncating tail", text: text("A long line that is truncated at the end because it doesn't fit")),
      Case(name: "truncating head", text: text("A long line that is truncated at the start because it doesn't fit"), lineBreakMode: .byTruncatingHead),
      Case(name: "truncating middle", text: text("A long line that is truncated in the middle because it doesn't fit"), lineBreakMode: .byTruncatingMiddle),
      Case(name: "character wrap", text: text(paragraph), lines: 0, lineBreakMode: .byCharWrapping),
      Case(name: "clipping", text: text("A long line that is clipped because it doesn't fit in the label"), lineBreakMode: .byClipping),
      Case(name: "two lines truncated", text: text(paragraph + " " + paragraph), lines: 2),
      Case(name: "inset", text: text("Inset text", [.font: NSFont.boldSystemFont(ofSize: 17), .foregroundColor: NSColor.red]), inset: CGSize(width: 6, height: 4)),
      Case(name: "empty", text: text("")),
      // decorations
      Case(name: "underline", text: text("Underlined text", [.underlineStyle: NSUnderlineStyle.single.rawValue])),
      Case(name: "underline dotted", text: text("Dotted underline", [.underlineStyle: NSUnderlineStyle.single.union(.patternDot).rawValue])),
      Case(name: "underline dashed", text: text("Dashed underline", [.underlineStyle: NSUnderlineStyle.single.union(.patternDash).rawValue])),
      Case(name: "underline by word", text: text("Underlined by word", [.underlineStyle: NSUnderlineStyle.single.union(.byWord).rawValue])),
      Case(name: "underline color", text: text("Red underline", [.underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: NSColor.red])),
      Case(name: "underline wrapped", text: text(paragraph, [.underlineStyle: NSUnderlineStyle.single.rawValue]), lines: 0, lineBreakMode: wrap),
      Case(name: "shadow sharp", text: text("Sharp shadow", [.shadow: shadow(offset: CGSize(width: 2, height: 2), blur: 0, color: .red)])),
      Case(name: "shadow blurred", text: text("Blurred shadow", [.shadow: shadow(offset: CGSize(width: 0, height: -1), blur: 3, color: .black)])),
      Case(name: "shadow translucent", text: text("Translucent shadow", [.shadow: shadow(offset: CGSize(width: 1, height: 1), blur: 1, color: NSColor.black.withAlphaComponent(0.4))])),
      Case(name: "baseline offset", text: text("Lowered text", [.baselineOffset: -3])),
      Case(name: "obliqueness", text: text("Slanted text", [.obliqueness: 0.3])),
      Case(name: "expansion", text: text("Expanded text", [.expansion: 0.3])),
      Case(name: "kern", text: text("Loose kern", [.kern: 2])),
      Case(name: "ligatures off", text: text("office flight", [.font: NSFont(name: "Times New Roman", size: 18) ?? NSFont.systemFont(ofSize: 18), .ligature: 0])),
      Case(name: "superscript", text: text("E = mc2", [.superscript: 1])),
      Case(name: "writing direction", text: text("Embedded direction", [.writingDirection: [NSWritingDirection.rightToLeft.rawValue | NSWritingDirectionFormatType.embedding.rawValue]])),
      Case(name: "link", text: link),
    ]
    if #available(macOS 11.0, *) {
      cases.append(Case(name: "tracking", text: text("Tracked text", [.tracking: 2])))
    }
    return cases
  }

  /// The texts with a style that a label keeps AppKit's drawing for.
  private static func unverifiedCases() -> [Case] {
    let attachment = NSTextAttachment()
    attachment.image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
      NSColor.blue.setFill()
      rect.fill()
      return true
    }
    let withAttachment = NSMutableAttributedString(attributedString: text("Image "))
    withAttachment.append(NSAttributedString(attachment: attachment))
    return [
      Case(name: "strikethrough", text: text("Struck through text", [.strikethroughStyle: NSUnderlineStyle.single.rawValue])),
      Case(name: "emoji", text: text("Emoji 😀🎉")),
      Case(name: "attachment", text: withAttachment),
      Case(name: "background", text: text("Background color", [.backgroundColor: NSColor.yellow])),
      Case(name: "underline thick", text: text("Thick underline", [.underlineStyle: NSUnderlineStyle.thick.rawValue])),
      Case(name: "underline double", text: text("Double underline", [.underlineStyle: NSUnderlineStyle.double.rawValue])),
      Case(name: "stroke outline", text: text("Outlined", [.strokeWidth: 3, .strokeColor: NSColor.blue])),
      Case(name: "custom style", text: text("Custom style", [NSAttributedString.Key("com.example.custom"): true])),
    ]
  }
}

#endif
