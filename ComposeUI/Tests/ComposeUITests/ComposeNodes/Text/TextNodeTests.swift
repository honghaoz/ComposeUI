//
//  TextNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/31/25.
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

import ChouTiTest

@testable import ComposeUI

class TextNodeTests: XCTestCase {

  func test_defaultSize() {
    // given: a text node
    var node = TextNode("Hello, world!")

    // when: laying out the node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the sizing is flexible and the size fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 50)
  }

  func test_fixedSize() throws {
    // given: a text node with a fixed size
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode("Hello, world!", font: font).fixedSize()

    // when: laying out the node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the sizing and size are fixed to the text's intrinsic size
    #if canImport(AppKit)
    expect(sizing) == ComposeNodeSizing(width: .fixed(51), height: .fixed(44))
    expect(node.size) == CGSize(width: 51, height: 44)
    #endif
    #if canImport(UIKit)
    expect(sizing) == ComposeNodeSizing(width: .fixed(51), height: .fixed(43))
    expect(node.size) == CGSize(width: 51, height: 43)
    #endif
  }

  func test_longString_multipleLines() throws {
    // given: a fixed size text node with a long string and unlimited lines
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode(
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      font: font
    )
    .numberOfLines(0)
    .fixedSize()

    // when: laying out the node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the text wraps to multiple lines within the container width
    expect(sizing) == ComposeNodeSizing(width: .fixed(100), height: .fixed(280))
    expect(node.size) == CGSize(width: 100, height: 280)
  }

  func test_longString_singleLine() throws {
    // given: a fixed size text node with a long string and a single line
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode(
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut",
      font: font
    )
    .numberOfLines(1)
    .fixedSize()

    // when: laying out the node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 1000, height: 50), context: context)

    // then: the text is sized to a single line
    expect(sizing) == ComposeNodeSizing(width: .fixed(751.0), height: .fixed(22))
    expect(node.size) == CGSize(width: 751.0, height: 22)
  }

  func test_unselectableText_showsInALabelViewWithTheNodesSettings() throws {
    // given: a compose view in the light theme, with a text node that's neither editable nor selectable, with settings
    // and a themed color
    var renderedView: TextLabelView?
    let contentView = ComposeView {
      TextNode(NSAttributedString(string: "Hello", attributes: [.themedForegroundColor: ThemedColor(light: .red, dark: .blue)]))
        .selectable(false)
        .numberOfLines(2)
        .lineBreakMode(.byTruncatingTail)
        .textContainerInset(horizontal: 4, vertical: 2)
        .onUpdate { item, _ in
          renderedView = item.view as? TextLabelView
        }
    }
    contentView.overrideTheme = .light
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    // when: rendering it
    contentView.refresh(animated: false)

    // then: the text shows in a label view, with the node's settings and the theme's color
    let labelView = try renderedView.unwrap()
    expect(labelView.attributedString.string) == "Hello"
    expect(labelView.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? Color) == .red
    expect(labelView.numberOfLines) == 2
    expect(labelView.lineBreakMode) == .byTruncatingTail
    expect(labelView.textContainerInset) == CGSize(width: 4, height: 2)

    // when: the theme changes to dark, and the view refreshes
    contentView.overrideTheme = .dark
    contentView.refresh(animated: false)

    // then: the label view shows the text in the dark theme's color
    expect(renderedView) === labelView
    expect(labelView.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? Color) == .blue
  }

  func test_selectableChange_replacesTheLabelViewWithATextView() throws {
    // given: a compose view with a text node that isn't selectable, shown in a label view
    var isSelectable = false
    var renderedView: View?
    let contentView = ComposeView {
      TextNode("Hello")
        .selectable(isSelectable)
        .onUpdate { item, _ in
          renderedView = item.view
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh(animated: false)
    let labelView = try (renderedView as? TextLabelView).unwrap()

    // when: the text node becomes selectable
    isSelectable = true
    contentView.refresh(animated: false)

    // then: a selectable text view showing the text replaces the label view
    let textView = try (renderedView as? BaseTextView).unwrap()
    expect(textView.isSelectable) == true
    expect(textView.attributedString.string) == "Hello"
    expect(textView.superview) != nil
    expect(labelView.superview) == nil

    // when: the text node isn't selectable again
    isSelectable = false
    contentView.refresh(animated: false)

    // then: a label view replaces the text view
    expect((renderedView as? TextLabelView)?.attributedString.string) == "Hello"
    expect(textView.superview) == nil
  }

  func test_view() {
    // given: a compose view with a default text node
    var textView: TextView?
    let contentView = ComposeView {
      TextNode("Hello, world!")
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }

    // when: the view is sized and refreshed
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    // then: the text view is selectable and interactive but not editable
    #if !os(tvOS)
    expect(textView?.isEditable) == false
    #endif
    expect(textView?.isSelectable) == true

    #if canImport(AppKit)
    expect(textView?.ignoreHitTest) == false
    #endif
    #if canImport(UIKit)
    expect(textView?.isUserInteractionEnabled) == true
    #endif

    // when: the content is updated to a non-selectable, non-editable text node
    var labelView: TextLabelView?
    contentView.setContent {
      TextNode("Hello, world!")
        .selectable(false)
        .editable(false)
        .onUpdate { item, _ in
          labelView = item.view as? TextLabelView
        }
    }
    contentView.refresh()

    // then: the text shows in a label view instead of a text view, which isn't interactive
    expect(labelView?.attributedString.string) == "Hello, world!"
    #if canImport(AppKit)
    expect(labelView?.hitTest(CGPoint(x: 1, y: 1))) == nil
    #endif
    #if canImport(UIKit)
    expect(labelView?.isUserInteractionEnabled) == false
    #endif

    // when: the content is updated to a selectable, editable text node
    contentView.setContent {
      TextNode("Hello, world!")
        .selectable()
        .editable()
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }
    contentView.refresh()

    // then: the text view is selectable, editable, and interactive
    #if !os(tvOS)
    expect(textView?.isEditable) == true
    #endif
    expect(textView?.isSelectable) == true

    #if canImport(AppKit)
    expect(textView?.ignoreHitTest) == false
    #endif
    #if canImport(UIKit)
    expect(textView?.isUserInteractionEnabled) == true
    #endif

    // when: the content is updated with a custom text container inset
    contentView.setContent {
      TextNode("Hello, world!")
        .textContainerInset(horizontal: 10, vertical: 20)
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }
    contentView.refresh()

    // then: the text view uses the inset
    #if canImport(AppKit)
    expect(textView?.textContainerInset) == CGSize(width: 10, height: 20)
    #endif

    #if canImport(UIKit)
    expect(textView?.textContainerInset) == EdgeInsets(top: 20, left: 10, bottom: 20, right: 10)
    #endif
  }

  func test_boundsChange_keepsTextUntilRefresh() throws {
    // given: fixed-size text whose configuration depends on the container width
    var renderedView: BaseTextView?
    let contentView = ComposeView { container in
      let isWide = container.frame.width >= 150
      TextNode(isWide ? "Expanded" : "Compact", font: .systemFont(ofSize: isWide ? 20 : 12))
        .frame(width: 100, height: 50)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)

    // then: the narrow configuration is rendered
    expect(textView.attributedString.string) == "Compact"
    expect(textView.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? Font) == Font.systemFont(ofSize: 12)

    // when: the container crosses the width threshold
    contentView.frame.size.width = 200
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the same fixed-size view keeps its configured text and font
    expect(renderedView) === textView
    expect(textView.bounds.size) == CGSize(width: 100, height: 50)
    expect(textView.attributedString.string) == "Compact"
    expect(textView.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? Font) == Font.systemFont(ofSize: 12)

    // when: an explicit refresh reevaluates the text
    contentView.refresh(animated: false)

    // then: the same view receives the rebuilt text and font
    expect(renderedView) === textView
    expect(textView.attributedString.string) == "Expanded"
    expect(textView.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? Font) == Font.systemFont(ofSize: 20)
    #if canImport(AppKit)
    expect(textView.string) == "Expanded"
    #endif
    #if canImport(UIKit)
    expect(textView.attributedText.string) == "Expanded"
    #endif
  }

  func test_refresh_appliesChangedAttributesAndEmptyText() throws {
    // given: a rendered text node with configurable attributed text
    var text = NSAttributedString(string: "Text", attributes: [.font: Font.systemFont(ofSize: 12)])
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)

    // when: attributes change without changing the string during resize
    text = NSAttributedString(string: "Text", attributes: [.font: Font.systemFont(ofSize: 20)])
    contentView.frame.size.width = 150
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: resizing keeps the configured font
    expect(textView.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? Font) == Font.systemFont(ofSize: 12)

    // when: an explicit refresh applies the changed attributes
    contentView.refresh(animated: false)

    // then: the changed font is applied to the text storage
    expect(renderedView) === textView
    expect(textView.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? Font) == Font.systemFont(ofSize: 20)
    #if canImport(AppKit)
    expect(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? Font) == Font.systemFont(ofSize: 20)
    #endif
    #if canImport(UIKit)
    expect(textView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? Font) == Font.systemFont(ofSize: 20)
    #endif

    // when: the configured text becomes empty during resize
    text = NSAttributedString()
    contentView.frame.size.width = 200
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: resizing keeps the previous text
    expect(textView.attributedString.string) == "Text"

    // when: an explicit refresh applies the empty text
    contentView.refresh(animated: false)

    // then: the previous text is cleared
    expect(textView.attributedString.length) == 0
    #if canImport(AppKit)
    expect(textView.string) == ""
    #endif
    #if canImport(UIKit)
    expect(textView.attributedText.length) == 0
    #endif

    // when: another resize leaves the configured text empty
    contentView.frame.size.width = 250
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the empty configuration remains valid
    expect(renderedView) === textView
    expect(textView.attributedString.length) == 0
  }

  func test_refresh_sameText_reusesTheThemedTextUntilTheThemeChanges() throws {
    // given: a rendered text node whose text is one object with a themed color, in the light theme
    let text = NSAttributedString(string: "Text", attributes: [.themedForegroundColor: ThemedColor(light: .red, dark: .blue)])
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.overrideTheme = .light
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    let lightText = textView.attributedString

    // when: refreshing with the same text and theme
    contentView.refresh(animated: false)

    // then: the text view shows the same themed text, in the light color
    expect(renderedView) === textView
    expect(textView.attributedString) === lightText
    expect(shownForegroundColor(of: textView)) == .red

    // when: the theme changes and the content refreshes
    contentView.overrideTheme = .dark
    contentView.refresh(animated: false)

    // then: the text view shows a new themed text, in the dark color
    expect(textView.attributedString) !== lightText
    expect(shownForegroundColor(of: textView)) == .blue
  }

  func test_refresh_textWithoutThemedAttributes_showsTheTextItself() throws {
    // given: a text node of a text without themed attributes, in the light theme
    let text = NSAttributedString(string: "Text", attributes: [.foregroundColor: Color.red])
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.overrideTheme = .light

    // when: rendering it
    contentView.refresh(animated: false)

    // then: the text view shows the text itself, instead of a copy with a theme applied
    let textView = try unwrap(renderedView)
    expect(textView.attributedString) === text
    expect(shownForegroundColor(of: textView)) == .red

    // when: the theme changes and the content refreshes
    contentView.overrideTheme = .dark
    contentView.refresh(animated: false)

    // then: the text view still shows the text itself, whose color is the same in both themes
    expect(textView.attributedString) === text
    expect(shownForegroundColor(of: textView)) == .red
  }

  func test_attributedString_colorsTheSameInBothThemes_areSetAsTheyAre() {
    // given: the colors of a simple text, the same in both themes or not
    let sameColor = ThemedColor(light: .red, dark: .red)
    let themedColor = ThemedColor(light: .red, dark: .blue)

    // when: making the attributed strings of simple text with them
    let plainText = TextNode.attributedString("Text", font: .systemFont(ofSize: 13), foregroundColor: sameColor, backgroundColor: sameColor, shadow: nil, textAlignment: .natural, lineBreakMode: .byWordWrapping)
    let themedText = TextNode.attributedString("Text", font: .systemFont(ofSize: 13), foregroundColor: themedColor, backgroundColor: themedColor, shadow: nil, textAlignment: .natural, lineBreakMode: .byWordWrapping)

    // then: a color that's the same in both themes is set as it is, which leaves the text nothing to apply a theme to,
    // and a color that differs is set as a themed color
    let plainAttributes = plainText.attributes(at: 0, effectiveRange: nil)
    expect(plainAttributes[.foregroundColor] as? Color) == .red
    expect(plainAttributes[.backgroundColor] as? Color) == .red
    expect(plainText.hasThemedAttributes) == false
    let themedAttributes = themedText.attributes(at: 0, effectiveRange: nil)
    expect(themedAttributes[.themedForegroundColor] as? ThemedColor) == themedColor
    expect(themedAttributes[.themedBackgroundColor] as? ThemedColor) == themedColor
    expect(themedAttributes[.foregroundColor]) == nil
    expect(themedAttributes[.backgroundColor]) == nil
  }

  func test_refresh_mutableTextChangedInPlace_showsTheChangedText() throws {
    // given: a rendered text node whose text is one mutable object with a themed color, in the light theme
    let text = NSMutableAttributedString(string: "Text", attributes: [.themedForegroundColor: ThemedColor(light: .red, dark: .blue)])
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.overrideTheme = .light
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)

    // when: the text changes in place and the content refreshes
    text.replaceCharacters(in: NSRange(location: 0, length: text.length), with: "Changed")
    contentView.refresh(animated: false)

    // then: the text view shows the changed text, in the light color
    expect(shownString(of: textView)) == "Changed"
    expect(shownForegroundColor(of: textView)) == .red
  }

  func test_refresh_sameTextAfterAnEdit_replacesTheEdit() throws {
    // given: a rendered editable text node whose text is one object, and the user's edit of the text view
    let text = NSAttributedString(string: "Configured text")
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .editable(true)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    #if canImport(AppKit)
    textView.string = "User edited text"
    #endif
    #if canImport(UIKit)
    textView.text = "User edited text"
    #endif
    expect(shownString(of: textView)) == "User edited text"

    // when: the content refreshes with the same text
    contentView.refresh(animated: false)

    // then: the configured text replaces the edit
    expect(shownString(of: textView)) == "Configured text"
  }

  #if canImport(AppKit) || canImport(UIKit) && !os(tvOS)
  func test_editable_showsTheTextWithoutResolvingItsWritingDirections() throws {
    let text = NSAttributedString(string: "مرحبا بالعالم")
    for isEditable in [false, true] {
      // given: a text node, editable or not, of a right-to-left text without a writing direction
      var renderedView: BaseTextView?
      let contentView = ComposeView {
        TextNode(text)
          .editable(isEditable)
          .onUpdate { item, _ in
            renderedView = item.view as? BaseTextView
          }
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)

      // when: rendering it in a new text view
      contentView.refresh(animated: false)

      // then: the text view shows the text in the direction of its text unless it's editable, which the node makes it
      // before setting its text
      let textView = try unwrap(renderedView)
      let shownText = try unwrap(shownAttributedText(of: textView))
      let shownStyle = shownText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
      let expectedText = isEditable ? text : text.resolvingNaturalWritingDirections()
      let expectedStyle = expectedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
      expect(shownStyle?.baseWritingDirection ?? .natural, "editable: \(isEditable)") == expectedStyle?.baseWritingDirection ?? .natural
    }
  }

  func test_editable_changedOnRefresh_showsTheTextForTheNewSetting() throws {
    // given: a rendered text node that isn't editable, of a right-to-left text without a writing direction
    let text = NSAttributedString(string: "مرحبا بالعالم")
    var isEditable = false
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .editable(isEditable)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    let direction = { [self] in
      (shownAttributedText(of: textView)?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.baseWritingDirection ?? .natural
    }
    let resolvedStyle = text.resolvingNaturalWritingDirections().attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle

    // when: the node becomes editable, with the same text, and the content refreshes
    isEditable = true
    contentView.refresh(animated: false)

    // then: the same text view shows the text without a writing direction, as an editable text view shows it
    expect(renderedView) === textView
    expect(direction()) == .natural

    // when: the node stops being editable, and the content refreshes
    isEditable = false
    contentView.refresh(animated: false)

    // then: the text view shows the text in its direction again
    expect(renderedView) === textView
    expect(direction()) == resolvedStyle?.baseWritingDirection ?? .natural
  }
  #endif

  #if canImport(UIKit) && !os(tvOS)
  func test_editable_newTextAfterTheUserTyped_removesTheUndoActions() throws {
    // given: an editable text node in a key window, whose text view the user typed into
    var text = "Hello"
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .editable()
        .frame(width: 300, height: 60)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    let window = TestWindow()
    window.rootViewController = UIViewController()
    window.rootViewController?.view.addSubview(contentView)
    window.makeKeyAndVisible()
    contentView.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    textView.becomeFirstResponder()
    textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)
    textView.insertText(", world and more")
    expect(textView.undoManager?.canUndo) == true

    // when: refreshing with a shorter text in the typing's pass of the run loop
    text = "Hi"
    contentView.refresh(animated: false)

    // then: the text is shown, and the undo actions are gone
    expect(renderedView) === textView
    expect(textView.textStorage.string) == "Hi"
    expect(textView.undoManager?.canUndo) == false
    withExtendedLifetime(window) {}
  }
  #endif

  func test_boundsChange_preservesEditingAndTextOptionsUntilRefresh() throws {
    // given: editable text with a selection and edits not yet reflected in its configuration
    var renderedView: BaseTextView?
    var numberOfLines = 0
    var lineBreakMode = NSLineBreakMode.byWordWrapping
    var inset: CGFloat = 0
    var isEditable = true
    let contentView = ComposeView {
      TextNode("Configured text")
        .editable(isEditable)
        .numberOfLines(numberOfLines)
        .lineBreakMode(lineBreakMode)
        .textContainerInset(horizontal: inset, vertical: inset * 2)
        .frame(width: .flexible, height: 300)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    let selection = NSRange(location: 2, length: 4)
    #if canImport(AppKit)
    textView.string = "User edited text"
    textView.setSelectedRange(selection)
    #endif
    #if canImport(UIKit)
    textView.text = "User edited text"
    textView.selectedRange = selection
    #endif

    // when: the reused text view scrolls
    contentView.contentOffset = CGPoint(x: 0, y: 20)
    contentView.layoutIfNeeded()

    // then: scrolling preserves the selection and edited text
    expect(textView.selectedRange) == selection
    #if canImport(AppKit)
    expect(textView.string) == "User edited text"
    #endif
    #if canImport(UIKit)
    expect(textView.text) == "User edited text"
    #endif

    // when: the view is resized while different text options await a refresh
    numberOfLines = 3
    lineBreakMode = .byClipping
    inset = 4
    contentView.frame.size.width = 200
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: resizing preserves editing and the configured text options
    expect(renderedView) === textView
    expect(textView.attributedString.string) == "Configured text"
    expect(textView.selectedRange) == selection
    expect(textView.numberOfLines) == 0
    expect(textView.lineBreakMode) == .byWordWrapping
    #if !os(tvOS)
    expect(textView.isEditable) == true
    #endif
    #if canImport(AppKit)
    expect(textView.string) == "User edited text"
    expect(textView.textContainerInset) == .zero
    #endif
    #if canImport(UIKit)
    expect(textView.text) == "User edited text"
    expect(textView.textContainerInset) == .zero
    #endif

    // when: an explicit refresh reapplies the model configuration
    contentView.refresh(animated: false)

    // then: explicit refresh applies the new options and configured text
    expect(textView.numberOfLines) == 3
    expect(textView.lineBreakMode) == .byClipping
    #if canImport(AppKit)
    expect(textView.string) == "Configured text"
    expect(textView.textContainerInset) == CGSize(width: 4, height: 8)
    #endif
    #if canImport(UIKit)
    expect(textView.text) == "Configured text"
    expect(textView.textContainerInset) == EdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    #endif

    // when: resizing changes an interaction option without changing configured text
    isEditable = false
    contentView.frame.size.width = 250
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: resizing keeps the interaction options
    #if !os(tvOS)
    expect(textView.isEditable) == true
    #endif

    // when: an explicit refresh applies the interaction options
    contentView.refresh(animated: false)

    // then: the reused text view applies the new interaction options, and stays interactive, since it's selectable
    expect(renderedView) === textView
    expect(textView.isSelectable) == true
    #if !os(tvOS)
    expect(textView.isEditable) == false
    #endif
    #if canImport(AppKit)
    expect(textView.ignoreHitTest) == false
    #endif
    #if canImport(UIKit)
    expect(textView.isUserInteractionEnabled) == true
    #endif
  }

  func test_boundsChange_reflowsExistingText() throws {
    // given: multiline text with configuration that can change on refresh
    let originalText = "A paragraph that wraps across several lines in a narrow container and fewer lines in a wide container."
    var text = originalText
    let font = Font.systemFont(ofSize: 14)
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text, font: font)
        .fixedSize(width: false, height: true)
        .onUpdate { renderable, _ in
          renderedView = renderable.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 500)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    let narrowHeight = textView.bounds.height
    text = "Different content"

    // when: the existing text is laid out with a wider proposal
    contentView.frame.size.width = 240
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the old configured text is measured and rendered at the new width
    var expectedNode = TextNode(originalText, font: font).fixedSize(width: false, height: true)
    _ = expectedNode.layout(containerSize: CGSize(width: 240, height: 500), context: ComposeNodeLayoutContext(scaleFactor: contentView.windowScaleFactor))
    expect(renderedView) === textView
    expect(textView.bounds.size) == expectedNode.size
    expect(textView.bounds.height) < narrowHeight
    expect(textView.attributedString.string) == originalText
    #if canImport(AppKit)
    expect(textView.string) == originalText
    #endif
    #if canImport(UIKit)
    expect(textView.text) == originalText
    #endif

    // when: an explicit refresh applies the new text
    contentView.refresh(animated: false)

    // then: measurement and rendering both use the new content
    var refreshedNode = TextNode(text, font: font).fixedSize(width: false, height: true)
    _ = refreshedNode.layout(containerSize: CGSize(width: 240, height: 500), context: ComposeNodeLayoutContext(scaleFactor: contentView.windowScaleFactor))
    expect(textView.bounds.size) == refreshedNode.size
    expect(textView.attributedString.string) == text
  }

  func test_renderableItems_reuseId_matchesTheInteractionSettings() throws {
    for (isEditable, isSelectable, expectedId) in [
      (false, true, "BaseTextView"),
      (false, false, "TextLabelView"),
      (true, true, "BaseTextView.editable"),
      (true, false, "BaseTextView.editable.unselectable"),
    ] {
      // given: a laid out text node with the interaction settings
      var node = TextNode("Hello").editable(isEditable).selectable(isSelectable)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

      // when: making its renderable item
      let item = try node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).first.unwrap()

      // then: the item's view is pooled with the views of the same interaction settings only
      expect(item.reuseId, expectedId) == ReuseId(namespace: .framework, id: expectedId)
    }
  }

  func test_appendRenderableItems_outsideTheVisibleBounds_appendsNothing() throws {
    // given: a laid out text node, and an array with another node's item
    var node = TextNode("Hello")
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
    var items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
    let existingItem = try items.first.unwrap()

    // when: appending its items for visible bounds that don't intersect it
    node.appendRenderableItems(in: CGRect(x: 0, y: 200, width: 100, height: 100), to: &items)

    // then: nothing is appended, and the existing item stays as it was
    expect(items.map(\.id)) == [existingItem.id]
    expect(items.map(\.frame)) == [existingItem.frame]
  }

  func test_reuse_textViewsOfTheSameInteractionSettings() throws {
    // given: a compose view with its own pool, showing an editable, unselectable text node
    var showsText = true
    var isSelectable = false
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      if showsText {
        TextNode("Hello", font: Font.systemFont(ofSize: 14))
          .editable()
          .selectable(isSelectable)
          .onUpdate { item, _ in
            renderedView = item.view as? BaseTextView
          }
      }
    }
    contentView.renderablePool = RenderablePool()
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let unselectableView = try unwrap(renderedView)

    // when: the text is removed, so its text view goes to the pool
    showsText = false
    contentView.refresh(animated: false)

    // then: the pooled text view keeps its interaction settings
    expect(unselectableView.isSelectable) == false

    // when: an editable, selectable text node is shown
    showsText = true
    isSelectable = true
    contentView.refresh(animated: false)

    // then: it gets a new text view, instead of the unselectable one, which it would have to make selectable
    let selectableView = try unwrap(renderedView)
    expect(selectableView) !== unselectableView
    expect(selectableView.isSelectable) == true

    // when: the text is removed, and an editable, unselectable text node is shown
    showsText = false
    contentView.refresh(animated: false)
    showsText = true
    isSelectable = false
    contentView.refresh(animated: false)

    // then: it reuses the unselectable text view, which is unselectable already
    expect(renderedView) === unselectableView
    expect(unselectableView.isSelectable) == false
  }

  #if canImport(UIKit)
  func test_reuse_inTheSameRenderPass_sameSize_replacesTheTextInOneEdit() throws {
    // given: a compose view with its own pool, showing a text node in a fixed frame, and an observer of its text view's
    // text storage edits
    var id = "first"
    var text = "First"
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text, font: Font.systemFont(ofSize: 14))
        .id(id)
        .frame(width: 100, height: 20)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.renderablePool = RenderablePool()
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    var editCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textView.textStorage, queue: nil) { _ in
      editCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: another text node of the same size replaces it, so one render pass removes the text view to the pool and
    // reuses it for the other text node, without resizing it
    id = "second"
    text = "Second"
    contentView.refresh(animated: false)

    // then: the text view replaces its text in one edit, since the reset for the pool keeps the text
    expect(renderedView) === textView
    expect(editCount) == 1
    expect(shownString(of: textView)) == "Second"
  }

  func test_reuse_inTheSameRenderPass_resized_removesTheTextBeforeTheResize() throws {
    // given: a compose view with its own pool, showing a text node of its text's size, and an observer that records its
    // text view's size at each edit of its text storage
    var id = "first"
    var text = "First"
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .fixedSize(width: true, height: true)
        .id(id)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.renderablePool = RenderablePool()
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    let firstSize = textView.frame.size
    var sizesAtEdits: [CGSize] = []
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textView.textStorage, queue: nil) { _ in
      sizesAtEdits.append(textView.frame.size)
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: a text node of another size replaces it, so one render pass removes the text view to the pool and reuses
    // it, resized, for the other text node
    id = "second"
    text = "Second, a longer text"
    contentView.refresh(animated: false)

    // then: the text view removes the old text before the resize, which would lay the old text out again, and then
    // shows the new text
    expect(renderedView) === textView
    expect(textView.frame.size) != firstSize
    expect(sizesAtEdits) == [firstSize, textView.frame.size]
    expect(shownString(of: textView)) == "Second, a longer text"
  }
  #endif

  func test_reuse_labelView_inTheSameRenderPass_replacesTheTextInOneEdit() throws {
    // given: a compose view with its own pool, showing a label, and an observer of its label view's text storage edits
    var id = "first"
    var text = "First"
    var renderedView: TextLabelView?
    let contentView = ComposeView {
      LabelNode(text)
        .id(id)
        .onUpdate { item, _ in
          renderedView = item.view as? TextLabelView
        }
    }
    contentView.renderablePool = RenderablePool()
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let labelView = try unwrap(renderedView)
    var editCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: labelView.test.textStorage, queue: nil) { _ in
      editCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: another label replaces it, so one render pass removes the label view to the pool and reuses it for the
    // other label
    id = "second"
    text = "Second"
    contentView.refresh(animated: false)

    // then: the label view replaces its text in one edit, since the reset for the pool keeps the text until the end of
    // the run loop turn, instead of removing it in an edit of its own
    expect(renderedView) === labelView
    expect(editCount) == 1
    expect(labelView.test.textStorage.string) == "Second"

    // when: the run loop turn ends
    let turnEnded = expectation(description: "the run loop turn ends")
    onNextRunLoop {
      turnEnded.fulfill()
    }
    wait(for: [turnEnded], timeout: 1)

    // then: the label view keeps the other label's text
    expect(labelView.test.textStorage.string) == "Second"
    expect(editCount) == 1
  }

  #if canImport(AppKit)
  func test_reuse_inTheSameRenderPass_replacesTheTextInOneEdit() throws {
    // given: a compose view with its own pool, showing a text node, and an observer of its text view's text storage
    // edits
    var id = "first"
    var text = "First"
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .id(id)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.renderablePool = RenderablePool()
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    let textStorage = try unwrap(textView.textStorage)
    var editCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textStorage, queue: nil) { _ in
      editCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: another text node replaces it, so one render pass removes the text view to the pool and reuses it for the
    // other text node
    id = "second"
    text = "Second"
    contentView.refresh(animated: false)

    // then: the text view replaces its text in one edit, since the reset for the pool keeps the text until the end of
    // the run loop turn, instead of removing it in an edit of its own
    expect(renderedView) === textView
    expect(editCount) == 1
    expect(shownString(of: textView)) == "Second"

    // when: the run loop turn ends
    let turnEnded = expectation(description: "the run loop turn ends")
    onNextRunLoop {
      turnEnded.fulfill()
    }
    wait(for: [turnEnded], timeout: 1)

    // then: the text view keeps the other text node's text
    expect(shownString(of: textView)) == "Second"
    expect(editCount) == 1
  }

  func test_editable_undoAllowed_newTextAfterTheUserTyped_removesTheUndoActions() throws {
    // given: an editable text node whose text view allows undo, in a window, whose text view the user typed into
    var text = "Hello"
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .editable()
        .frame(width: 300, height: 60)
        .onUpdate { item, _ in
          let textView = item.view as? BaseTextView
          textView?.allowsUndo = true
          renderedView = textView
        }
    }
    let window = TestWindow()
    window.contentView?.addSubview(contentView)
    contentView.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    let undoManager = try Self.type(", world and more", into: textView, in: window)

    // when: refreshing with a shorter text
    text = "Hi"
    contentView.refresh(animated: false)

    // then: the text is shown, and the undo actions are gone
    expect(renderedView) === textView
    expect(shownString(of: textView)) == "Hi"
    expect(undoManager.canUndo) == false
  }

  func test_reuse_undoAllowed_removesTheUndoActionsFromTheWindow() throws {
    // given: a compose view with its own pool, in a window, showing an editable text node whose text view allows undo,
    // which the user typed into
    var id = "first"
    var text = "Hello"
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(text)
        .editable()
        .id(id)
        .frame(width: 300, height: 60)
        .onUpdate { item, _ in
          let textView = item.view as? BaseTextView
          textView?.allowsUndo = true
          renderedView = textView
        }
    }
    contentView.renderablePool = RenderablePool()
    let window = TestWindow()
    window.contentView?.addSubview(contentView)
    contentView.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    let undoManager = try Self.type(", world and more", into: textView, in: window)

    // when: another node with the typed characters replaces it, and the render pass reuses its text view for it
    id = "second"
    text = "Hello, world and more"
    contentView.refresh(animated: false)

    // then: the undo actions are gone, since their undo would edit the other node's text
    expect(renderedView) === textView
    expect(undoManager.canUndo) == false
  }
  #endif

  func test_refresh_restoresTheSettingsChangedOnTheTextView() throws {
    // given: a text node rendered with its settings, whose text view's settings were then changed directly
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode("Hello", font: Font.systemFont(ofSize: 14))
        .numberOfLines(2)
        .lineBreakMode(.byTruncatingTail)
        .textContainerInset(horizontal: 4, vertical: 2)
        .onUpdate { item, _ in
          renderedView = item.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    textView.numberOfLines = 5
    textView.lineBreakMode = .byCharWrapping
    #if canImport(AppKit)
    textView.textContainerInset = CGSize(width: 10, height: 10)
    #endif
    #if canImport(UIKit)
    textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    #endif
    #if !os(tvOS)
    textView.isEditable = true
    #endif
    textView.isSelectable = false

    // when: refreshing
    contentView.refresh(animated: false)

    // then: the text view has the node's settings again, since each setting is compared with the text view's
    expect(textView.numberOfLines) == 2
    expect(textView.lineBreakMode) == .byTruncatingTail
    #if canImport(AppKit)
    expect(textView.textContainerInset) == CGSize(width: 4, height: 2)
    #endif
    #if canImport(UIKit)
    expect(textView.textContainerInset) == UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
    #endif
    #if !os(tvOS)
    expect(textView.isEditable) == false
    #endif
    expect(textView.isSelectable) == true
  }

  #if canImport(UIKit)
  func test_update_setsTheSettingsBeforeTheText() throws {
    for reusesTextView in [false, true] {
      // given: a compose view with its own pool, and for a reused text view, a text node that was shown and then
      // removed, so that the pool reset its text view
      let scenario = reusesTextView ? "reused text view" : "new text view"
      var showsText = reusesTextView
      var hasSettings = false
      var insertedTextView: BaseTextView?
      let contentView = ComposeView {
        if showsText {
          TextNode(hasSettings ? "Hello, world!" : "First", font: Font.systemFont(ofSize: 14))
            .numberOfLines(hasSettings ? 2 : 0)
            .lineBreakMode(hasSettings ? .byTruncatingTail : .byWordWrapping)
            .textContainerInset(horizontal: hasSettings ? 4 : 0, vertical: hasSettings ? 2 : 0)
            .willInsert { renderable, _ in
              insertedTextView = renderable.view as? BaseTextView
            }
        }
      }
      contentView.renderablePool = RenderablePool()
      contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
      contentView.refresh(animated: false)
      let firstTextView = insertedTextView
      showsText = false
      contentView.refresh(animated: false)

      // when: showing a text node with settings that aren't a text view's defaults, recording the text view's settings
      // each time its text storage processes an edit
      var settingsAtEdits: [(numberOfLines: Int, lineBreakMode: NSLineBreakMode, inset: UIEdgeInsets)] = []
      let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: nil, queue: nil) { notification in
        if let textView = insertedTextView, textView.textStorage === notification.object as AnyObject? {
          settingsAtEdits.append((textView.numberOfLines, textView.lineBreakMode, textView.textContainerInset))
        }
      }
      defer {
        NotificationCenter.default.removeObserver(observer)
      }
      insertedTextView = nil
      showsText = true
      hasSettings = true
      contentView.refresh(animated: false)

      // then: the text view has the node's settings when it gets the text, so that setting them doesn't invalidate the
      // layout of a text in place
      let textView = try unwrap(insertedTextView)
      if reusesTextView {
        expect(textView, scenario) === firstTextView
      }
      expect(settingsAtEdits.isEmpty, scenario) == false
      for settings in settingsAtEdits {
        expect(settings.numberOfLines, scenario) == 2
        expect(settings.lineBreakMode, scenario) == .byTruncatingTail
        expect(settings.inset, scenario) == UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
      }
    }
  }

  func test_notEditable_textViewStopsTheTextAtItsBounds() throws {
    // given: a compose view showing a text node that isn't editable, in a frame smaller than its text, whose frame then
    // changes, after which a UIKit text view that scrolls lays out its whole text
    var width: CGFloat = 120
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(Constants.textTallerThanItsFrame, font: Font.systemFont(ofSize: 14))
        .frame(width: width, height: 40)
        .onUpdate { renderable, _ in
          renderedView = renderable.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)

    // when: the frame changes
    width = 140
    contentView.refresh(animated: false)

    // then: the text view doesn't scroll, and lays out only the text in its bounds, as on AppKit
    let textView = try unwrap(renderedView)
    expect(textView.bounds.size) == CGSize(width: 140, height: 40)
    expect(textView.isScrollEnabled) == false
    expect(Self.laidOutGlyphCount(of: textView)) < textView.layoutManager.numberOfGlyphs
  }

  func test_editable_textViewScrollsToTheTextPastItsBounds() throws {
    // given: a compose view showing an editable text node, in a frame smaller than its text, whose frame then changes
    var width: CGFloat = 120
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(Constants.textTallerThanItsFrame, font: Font.systemFont(ofSize: 14))
        .editable()
        .frame(width: width, height: 40)
        .onUpdate { renderable, _ in
          renderedView = renderable.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)

    // when: the frame changes
    width = 140
    contentView.refresh(animated: false)

    // then: the text view scrolls, and lays out its whole text, past its bounds, so that the user reaches it
    let textView = try unwrap(renderedView)
    expect(textView.bounds.size) == CGSize(width: 140, height: 40)
    expect(textView.isScrollEnabled) == true
    expect(Self.laidOutGlyphCount(of: textView)) == textView.layoutManager.numberOfGlyphs
    expect(textView.contentSize.height) > textView.bounds.height
  }

  func test_editableChangedToNotEditable_scrolledTextView_showsTheTextFromItsTop() throws {
    // given: a compose view showing an editable text node, in a frame smaller than its text, whose frame changed, so
    // that its text view laid out its whole text, and which the user scrolled down
    var isEditable = true
    var width: CGFloat = 120
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(Constants.textTallerThanItsFrame, font: Font.systemFont(ofSize: 14))
        .editable(isEditable)
        .frame(width: width, height: 40)
        .onUpdate { renderable, _ in
          renderedView = renderable.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    width = 140
    contentView.refresh(animated: false)
    let textView = try unwrap(renderedView)
    textView.contentOffset = CGPoint(x: 0, y: 30)
    expect(textView.contentOffset) == CGPoint(x: 0, y: 30)

    // when: the text node stops being editable
    isEditable = false
    contentView.refresh(animated: false)

    // then: the same text view stops scrolling, and shows its text from its top, where it lays the text out
    expect(renderedView) === textView
    expect(textView.isScrollEnabled) == false
    expect(textView.contentOffset) == .zero
    expect(Self.laidOutGlyphCount(of: textView)) < textView.layoutManager.numberOfGlyphs
  }

  func test_resize_subviewThatAnAppAdded_isAutoresized() {
    // given: a compose view showing a text node in a frame, whose text view an app added a subview to, which
    // autoresizes its width with the text view
    var width: CGFloat = 120
    let subview = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 10))
    subview.autoresizingMask = [.flexibleWidth]
    let contentView = ComposeView {
      TextNode("Hello", font: Font.systemFont(ofSize: 14))
        .frame(width: width, height: 40)
        .onInsert { renderable, _ in
          renderable.view?.addSubview(subview)
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)

    // when: the frame grows
    width = 160
    contentView.refresh(animated: false)

    // then: the subview is autoresized with the text view
    expect(subview.frame) == CGRect(x: 0, y: 0, width: 160, height: 10)
  }

  func test_resize_textViewLaysOutItsSubviewsForTheNewSize() throws {
    // given: a compose view showing a text node with an inset, in a frame
    var size = CGSize(width: 120, height: 40)
    var renderedView: BaseTextView?
    let contentView = ComposeView {
      TextNode(Constants.textTallerThanItsFrame, font: Font.systemFont(ofSize: 14))
        .textContainerInset(horizontal: 4, vertical: 2)
        .frame(width: size.width, height: size.height)
        .onUpdate { renderable, _ in
          renderedView = renderable.view as? BaseTextView
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)

    // when: the frame grows
    size = CGSize(width: 160, height: 60)
    contentView.refresh(animated: false)

    // then: the text view, which skips autoresizing its subviews, since none has an autoresizing mask, fits its text
    // container view and its text container in its new size
    let textView = try unwrap(renderedView)
    textView.layoutIfNeeded()
    let textContainerView = try unwrap(textView.subviews.first { String(cString: object_getClassName($0)) == "_UITextContainerView" })
    expect(textView.bounds.size) == CGSize(width: 160, height: 60)
    expect(textContainerView.frame) == textView.bounds
    expect(textView.textContainer.size) == CGSize(width: 152, height: 56)
  }
  #endif

  #if canImport(AppKit)
  func test_refresh_insetChangedOnly_relaysOutTheTextContainer() throws {
    for keepsTheTextObject in [false, true] {
      // given: text that wraps across several lines, rendered 200 points wide in a new text view, made of the same text
      // object on each refresh, as a label's text is, or of a new one
      let string = "A paragraph that wraps across several lines in a narrow container and fewer lines in a wide container."
      let keptNode = TextNode(string, font: Font.systemFont(ofSize: 14))
      var inset: CGFloat = 0
      var renderedView: BaseTextView?
      let contentView = ComposeView {
        (keepsTheTextObject ? keptNode : TextNode(string, font: Font.systemFont(ofSize: 14)))
          .textContainerInset(horizontal: inset, vertical: 0)
          .frame(width: .flexible, height: 300)
          .onUpdate { item, _ in
            renderedView = item.view as? BaseTextView
          }
      }
      contentView.renderablePool = RenderablePool()
      contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 300)
      contentView.refresh(animated: false)
      let textView = try unwrap(renderedView)
      let scenario = keepsTheTextObject ? "same text object" : "new text object"
      let lineCountAt200 = lineCount(of: textView)

      // when: changing only the horizontal inset, and refreshing
      inset = 30
      contentView.refresh(animated: false)

      // then: the text container is 140 points wide, and the text wraps in it as after an explicit layout
      expect(textView.textContainer?.size.width, scenario) == 140
      let lineCountAfterRefresh = lineCount(of: textView)
      textView.needsLayout = true
      textView.layoutSubtreeIfNeeded()
      expect(lineCountAfterRefresh, scenario) == lineCount(of: textView)
      expect(lineCountAfterRefresh, scenario) > lineCountAt200
    }
  }

  func test_refresh_widthChangedOnly_relaysOutTheTextContainer() throws {
    for keepsTheTextObject in [false, true] {
      // given: text that wraps across several lines, rendered 200 points wide in a new text view, made of the same text
      // object on each refresh, as a label's text is, or of a new one
      let string = "A paragraph that wraps across several lines in a narrow container and fewer lines in a wide container."
      let keptNode = TextNode(string, font: Font.systemFont(ofSize: 14))
      var width: CGFloat = 200
      var renderedView: BaseTextView?
      let contentView = ComposeView {
        (keepsTheTextObject ? keptNode : TextNode(string, font: Font.systemFont(ofSize: 14)))
          .frame(width: width, height: 300)
          .onUpdate { item, _ in
            renderedView = item.view as? BaseTextView
          }
      }
      contentView.renderablePool = RenderablePool()
      contentView.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
      contentView.refresh(animated: false)
      let textView = try unwrap(renderedView)
      let scenario = keepsTheTextObject ? "same text object" : "new text object"
      let lineCountAt200 = lineCount(of: textView)

      // when: changing only the text's width, and refreshing
      width = 140
      contentView.refresh(animated: false)

      // then: the text container is 140 points wide, and the text wraps in it as after an explicit layout
      expect(textView.textContainer?.size.width, scenario) == 140
      let lineCountAfterRefresh = lineCount(of: textView)
      textView.needsLayout = true
      textView.layoutSubtreeIfNeeded()
      expect(lineCountAfterRefresh, scenario) == lineCount(of: textView)
      expect(lineCountAfterRefresh, scenario) > lineCountAt200
    }
  }

  #endif

  func test_adjustIntrinsicTextSize() throws {
    // given: a fixed size text node with an intrinsic text size adjustment
    var textView: BaseTextView?
    let view = ComposeView {
      try TextNode("Hello, world!", font: unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(1)
        .fixedSize()
        .intrinsicTextSizeAdjustment { original in
          CGSize(width: 10, height: 20)
        }
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    // when: the view is sized and refreshed
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    view.refresh()

    // then: the text view size includes the adjustment
    expect(textView?.bounds.size) == CGSize(width: 83, height: 36)
  }

  func test_renderableItems_doesNotRetainNodeThroughItemCache() {
    // The cached item's `update` closure must not capture `self` (the node holds the item cache), else
    // itemCache -> cachedItem -> update -> self -> itemCache leaks the node when the tree is replaced.

    // given: a weak probe captured by the node's intrinsic size adjustment closure
    weak var weakProbe: AnyObject?
    do {
      let probe = NSObject()
      weakProbe = probe
      // capture the probe via the node's intrinsic-size-adjustment closure; the cached update reaches it only if it
      // captures `self`.
      var node: any ComposeNode = TextNode("hi").intrinsicTextSizeAdjustment { original in
        _ = probe
        return original
      }

      // when: the node lays out, provides renderable items, and goes out of scope
      _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      _ = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    // then: the probe is released, so the cached item does not retain the node
    expect(weakProbe).to(beNil())
  }

  func test_renderableItems_copiesOfABase_selectableChange_notStale() {
    // Two copies of a base text node each take their own item slot when they're laid out. Changing `selectable` does not
    // change the frame, so the cache's frame key cannot detect it, and a copy sharing the base's slot would return the
    // base's cached (selectable) item.

    // given: two copies of a base text node, one with selectable disabled
    let base = TextNode("hi").fixedSize(width: true, height: true)
    var defaultView: View?
    var nonSelectableView: View?
    let view = ComposeView {
      VStack {
        base.onUpdate { item, _ in defaultView = item.view }
        base.selectable(false).onUpdate { item, _ in nonSelectableView = item.view }
      }
    }

    // when: the view is sized and refreshed
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    // then: each copy renders with its own selectable state
    expect((defaultView as? BaseTextView)?.isSelectable) == true // TextNode is selectable by default
    expect(nonSelectableView is TextLabelView) == true // would be a selectable text view (stale) if the copies shared the base's slot
  }

  func test_renderableItems_copyConfiguredAfterLayout_rendersItsOwnSetting() throws {
    // given: a text node that's laid out and has made its item, and a copy of it made non-selectable after the layout,
    // laid out with the same context, as a container that reconfigures a laid out child does
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    let containerSize = CGSize(width: 100, height: 100)
    let bounds = CGRect(origin: .zero, size: containerSize)
    var node = TextNode("hi")
    _ = node.layout(containerSize: containerSize, context: context)
    _ = node.renderableItems(in: bounds)
    var copy = node.selectable(false)
    _ = copy.layout(containerSize: containerSize, context: context)

    // when: rendering the copy's item
    let item = try copy.renderableItems(in: bounds).first.unwrap()
    let contentView = ComposeView()
    let renderable = item.make(RenderableMakeContext(initialFrame: nil, contentView: contentView))
    item.update(renderable, RenderableUpdateContext(
      updateType: .insert,
      oldFrame: .zero,
      newFrame: item.frame,
      previousRenderBounds: nil,
      renderBounds: bounds,
      animationTiming: nil,
      contentView: contentView,
      contentEvaluation: nil,
      animationDecision: ComposeView.AnimationDecision.disabled
    ))

    // then: the text shows in a label view, as a text that isn't selectable does, since the setter cleared the copy's slot,
    // so the copy took its own slot instead of returning the node's cached (selectable) item
    expect(renderable.view is TextLabelView) == true
  }

  // MARK: - Memory Layout

  func test_memoryLayout_takesAtMost120Bytes() {
    // then: a text node takes at most 120 bytes, since at 128 the compiler checks an optional text node out of line,
    // which makes each layout of a label, which holds an optional text node, about 100 instructions slower
    expect(MemoryLayout<TextNode>.stride) <= 120
  }

  // MARK: - Helpers

  /// Returns the string that the text view shows.
  private func shownString(of textView: BaseTextView) -> String? {
    #if canImport(AppKit)
    return textView.textStorage?.string
    #endif
    #if canImport(UIKit)
    return textView.attributedText.string
    #endif
  }

  /// Returns the text that the text view shows, with the attributes that it shows it with.
  private func shownAttributedText(of textView: BaseTextView) -> NSAttributedString? {
    #if canImport(AppKit)
    return textView.textStorage
    #endif
    #if canImport(UIKit)
    return textView.attributedText
    #endif
  }

  /// Returns the foreground color of the first character that the text view shows.
  private func shownForegroundColor(of textView: BaseTextView) -> Color? {
    #if canImport(AppKit)
    return textView.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? Color
    #endif
    #if canImport(UIKit)
    return textView.attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? Color
    #endif
  }

  #if canImport(UIKit)
  /// Returns the number of glyphs that the text view lays out in its text container.
  private static func laidOutGlyphCount(of textView: BaseTextView) -> Int {
    textView.layoutManager.glyphRange(for: textView.textContainer).length
  }
  #endif

  #if canImport(AppKit)
  /// Returns the number of lines the text view lays out its text in.
  private func lineCount(of textView: BaseTextView) -> Int {
    var count = 0
    if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
      layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(for: textContainer)) { _, _, _, _, _ in
        count += 1
      }
    }
    return count
  }

  /// Types a text at the end of a text view's text as the user does, in a pass of the run loop that then ends, and returns
  /// the undo manager that records the typing.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - textView: The text view to type into.
  ///   - window: The text view's window.
  private static func type(_ text: String, into textView: BaseTextView, in window: NSWindow) throws -> UndoManager {
    window.makeFirstResponder(textView)
    textView.setSelectedRange(NSRange(location: textView.textStorage?.length ?? 0, length: 0))
    textView.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    RunLoop.main.run(until: Date())
    let undoManager = try unwrap(window.undoManager)
    expect(undoManager.canUndo) == true
    return undoManager
  }
  #endif

  #if canImport(UIKit)

  // MARK: - Constants

  private enum Constants {

    /// A text taller than the frames that the tests show it in.
    static let textTallerThanItsFrame = "A paragraph that wraps across several lines in a narrow frame, and goes on past the bottom of the frame."
  }
  #endif
}
