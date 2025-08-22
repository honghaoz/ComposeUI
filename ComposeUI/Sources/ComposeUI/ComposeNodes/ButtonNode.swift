//
//  ButtonNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

/// A node that renders a button.
public struct ButtonNode: ComposeNode {

  private let makeButtonContent: (ButtonState, ComposeView?) -> ComposeContent
  private let onTap: () -> Void
  private var onDoubleTap: (() -> Void)?

  #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
  private var hapticFeedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle?
  #endif

  #if canImport(AppKit)
  private var shouldPerformKeyEquivalent: ((NSEvent) -> Bool)?
  #endif

  private var buttonNode: ComposeNode

  /// Creates a button node.
  ///
  /// - Parameters:
  ///   - content: The content of the button for different states.
  ///   - onTap: The action to perform when the button is tapped.
  public init(@ComposeContentBuilder content: @escaping (ButtonState) -> ComposeContent,
              onTap: @escaping () -> Void)
  {
    self.init(
      content: { state, _ in
        content(state)
      },
      onTap: onTap
    )
  }

  /// Creates a button node.
  ///
  /// - Parameters:
  ///   - content: The content of the button for different states and the button view.
  ///   - onTap: The action to perform when the button is tapped.
  public init(@ComposeContentBuilder content: @escaping (ButtonState, ComposeView?) -> ComposeContent,
              onTap: @escaping () -> Void)
  {
    makeButtonContent = content
    self.onTap = onTap

    buttonNode = content(.normal, nil).asVStack()
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.button)

  public var size: CGSize { buttonNode.size }

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    buttonNode.layout(containerSize: containerSize, context: context)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let viewItem = ViewItem<ButtonView>(
      id: id,
      frame: frame,
      make: { ButtonView(frame: $0.initialFrame ?? .zero) },
      update: { view, context in
        switch context.updateType {
        case .insert,
             .refresh,
             .boundsChange:
          break
        case .scroll:
          return
        }

        view.configure(content: makeButtonContent, onTap: onTap)
        view.onDoubleTap = onDoubleTap
        #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
        view.hapticFeedbackStyle = hapticFeedbackStyle
        #endif
        #if canImport(AppKit)
        view.shouldPerformKeyEquivalent = shouldPerformKeyEquivalent
        #endif
      }
    )

    return [viewItem.eraseToRenderableItem()]
  }

  // MARK: - Public

  /// Set the action to perform when the button is double tapped.
  ///
  /// - Parameter block: The action to perform when the button is double tapped.
  public func onDoubleTap(block: @escaping () -> Void) -> Self {
    var copy = self
    copy.onDoubleTap = block
    return copy
  }

  #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
  /// Set the style of haptic feedback to be used when the button is pressed.
  ///
  /// - Parameter style: The style of haptic feedback to be used when the button is pressed.
  public func hapticFeedbackStyle(_ style: UIImpactFeedbackGenerator.FeedbackStyle?) -> Self {
    var copy = self
    copy.hapticFeedbackStyle = style
    return copy
  }
  #endif

  #if canImport(AppKit)
  /// Set the closure that determines whether the button should perform a key equivalent.
  ///
  /// - Parameter block: The closure that determines whether the button should perform a key equivalent.
  public func shouldPerformKeyEquivalent(_ block: @escaping (NSEvent) -> Bool) -> Self {
    var copy = self
    copy.shouldPerformKeyEquivalent = block
    return copy
  }
  #endif
}
