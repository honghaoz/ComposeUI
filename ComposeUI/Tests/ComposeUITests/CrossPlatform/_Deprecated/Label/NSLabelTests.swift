//
//  NSLabelTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/18/20.
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

//  #if canImport(AppKit)
//
//  import AppKit
//
//  import ChouTiTest
//
//  @_spi(Private) @testable import ComposeUI
//
//  class NSLabelTests: XCTestCase {
//
//    func testCellClass() {
//      // "Optional(ComposeUI.(unknown context at $1039d9be4).TextFieldCell)"
//      // "Optional(ComposeUI.TextFieldCell)"
//      let cellClassString = String(describing: NSLabel.cellClass)
//      let pattern = #"Optional\(ComposeUI(\.?.*?)\.TextFieldCell\)"#
//      expect(cellClassString.range(of: pattern, options: .regularExpression), cellClassString) != nil
//
//      // set cell class has no effect
//      Label.cellClass = NSTextFieldCell.self
//      let updatedCellClassString = String(describing: NSLabel.cellClass)
//      expect(updatedCellClassString.range(of: pattern, options: .regularExpression)) != nil
//    }
//
//    func testVerticalAlignment() {
//      let label = NSLabel()
//      expect(label.verticalAlignment) == .center
//
//      label.verticalAlignment = .top
//      expect(label.verticalAlignment) == .top
//    }
//
//    func testText() {
//      let label = NSLabel()
//      expect(label.text) == ""
//      expect(label.stringValue) == ""
//
//      label.text = "Hello, world!"
//      expect(label.text) == "Hello, world!"
//      expect(label.stringValue) == "Hello, world!"
//
//      label.text = nil
//      expect(label.text) == ""
//      expect(label.stringValue) == ""
//    }
//
//    func testMultilineTruncatesLastVisibleLine() {
//      let label = NSLabel()
//      expect(label.multilineTruncatesLastVisibleLine) == false
//
//      label.multilineTruncatesLastVisibleLine = true
//      expect(label.multilineTruncatesLastVisibleLine) == true
//    }
//
//    func testCommonInit() {
//      let label = NSLabel()
//      expect(label.layerContentsRedrawPolicy) == .onSetNeedsDisplay
//      expect(label.maximumNumberOfLines) == 1
//      expect(label.cell?.truncatesLastVisibleLine) == false
//
//      expect(label.wantsLayer) == true
//      expect(label.layer?.cornerCurve) == .circular
//      expect(label.layer?.contentsScale) == NSScreen.main?.backingScaleFactor ?? Constants.defaultScaleFactor
//      expect(label.layer?.masksToBounds) == false
//
//      expect(label.refusesFirstResponder) == true
//
//      expect(label.isEditable) == false
//      expect(label.isSelectable) == false
//      expect(label.allowsEditingTextAttributes) == false
//
//      expect(label.drawsBackground) == false
//      expect(label.isBezeled) == false
//      expect(label.isBordered) == false
//
//      expect(label.backgroundColor) == .clear
//      expect(label.ignoreHitTest) == true
//    }
//
//    func testSetToSingleLineMode() {
//      let label = NSLabel()
//
//      label.setToSingleLineMode(truncationMode: .none)
//      expect(label.lineBreakMode) == .byClipping
//      expect(label.multilineTruncatesLastVisibleLine) == false
//
//      label.setToSingleLineMode(truncationMode: .head)
//      expect(label.lineBreakMode) == .byTruncatingHead
//      expect(label.multilineTruncatesLastVisibleLine) == false
//
//      label.setToSingleLineMode(truncationMode: .tail)
//      expect(label.lineBreakMode) == .byTruncatingTail
//      expect(label.multilineTruncatesLastVisibleLine) == false
//
//      label.setToSingleLineMode(truncationMode: .middle)
//      expect(label.lineBreakMode) == .byTruncatingMiddle
//      expect(label.multilineTruncatesLastVisibleLine) == false
//    }
//
//    func testSetToMultilineMode() {
//      let label = NSLabel()
//
//      label.setToMultilineMode(numberOfLines: 0, lineWrapMode: .byWord, truncatesLastVisibleLine: true)
//      expect(label.maximumNumberOfLines) == 0
//      expect(label.cell?.lineBreakMode) == .byWordWrapping
//      expect(label.multilineTruncatesLastVisibleLine) == true
//
//      label.setToMultilineMode(numberOfLines: 1, lineWrapMode: .byChar, truncatesLastVisibleLine: false)
//      expect(label.maximumNumberOfLines) == 1
//      expect(label.cell?.lineBreakMode) == .byCharWrapping
//      expect(label.multilineTruncatesLastVisibleLine) == false
//    }
//
//    func testSetToSelectable() {
//      let label = NSLabel()
//      label.setIsSelectable(true)
//      expect(label.isSelectable) == true
//      expect(label.allowsEditingTextAttributes) == true
//
//      label.setIsSelectable(false)
//      expect(label.isSelectable) == false
//      expect(label.allowsEditingTextAttributes) == false
//    }
//  }
//
//  class TextFieldCellTests: XCTestCase {
//
//    func testInit() {
//      let cell = TextFieldCell()
//      expect(cell.horizontalPadding) == 0
//      expect(cell.verticalAlignment) == .center
//    }
//
//    func testAdjustRect() {
//      let cell = TextFieldCell()
//      cell.stringValue = "hello world"
//      cell.font = NSFont.systemFont(ofSize: 32)
//      let boundingRect = NSRect(x: 0, y: 0, width: 100, height: 100)
//
//      // when vertical alignment is center
//      do {
//        let drawingRect = cell.drawingRect(forBounds: boundingRect)
//        expect(drawingRect) == CGRect(x: 0.0, y: 12.0, width: 100.0, height: 76.0)
//      }
//
//      // when vertical alignment is top
//      do {
//        cell.verticalAlignment = .top
//        let drawingRect = cell.drawingRect(forBounds: boundingRect)
//        expect(drawingRect) == CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100) // hmm, why this has height 100?
//      }
//
//      // when vertical alignment is bottom
//      do {
//        Assert.setTestAssertionFailureHandler { message, file, line, column in
//          expect(message) == "unsupported bottom alignment"
//        }
//
//        cell.verticalAlignment = .bottom
//        let drawingRect = cell.drawingRect(forBounds: boundingRect)
//        expect(drawingRect) == CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100)
//
//        Assert.resetTestAssertionFailureHandler()
//      }
//    }
//
//    func test_calls() {
//      let cell = TextFieldCell()
//      cell.stringValue = "hello world"
//      cell.font = NSFont.systemFont(ofSize: 32)
//      let boundingRect = NSRect(x: 0, y: 0, width: 100, height: 100)
//
//      cell.draw(withFrame: boundingRect, in: NSView())
//      cell.drawInterior(withFrame: boundingRect, in: NSView())
//
//      cell.edit(withFrame: boundingRect, in: NSView(), editor: NSText(), delegate: nil, event: nil)
//      cell.select(withFrame: boundingRect, in: NSView(), editor: NSText(), delegate: nil, start: 0, length: 0)
//    }
//  }
//
//  #endif
