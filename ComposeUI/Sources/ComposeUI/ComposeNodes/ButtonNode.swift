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

public enum ButtonState {
  case normal
  case hovered
  case pressed // highlighted
  case selected
  case disabled
}

/// A node that renders a button.
public struct ButtonNode: ComposeNode {

  private let makeButtonContent: (ButtonState) -> ComposeContent
  private let onTap: () -> Void
  private var onDoubleTap: (() -> Void)?

  private var buttonNode: ComposeNode

  /// Creates a button node.
  ///
  /// - Parameters:
  ///   - content: The content of the button for different states.
  ///   - onTap: The action to perform when the button is tapped.
  public init(
    @ComposeContentBuilder content: @escaping (ButtonState) -> ComposeContent,
    onTap: @escaping () -> Void
  ) {
    makeButtonContent = content
    self.onTap = onTap

    buttonNode = content(.normal).asVStack(alignment: .center)
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
        if context.type == .insert {
          view.configure(content: makeButtonContent, onTap: onTap)
          view.onDoubleTap = onDoubleTap
        }
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
}

// MARK: - ButtonView

// TODO: add unit test for double tap

private final class ButtonView: ComposeView, GestureRecognizerDelegate {

  private var buttonState: ButtonState = .normal {
    didSet {
      if buttonState != oldValue {
        refresh()
      }
    }
  }

  override var content: ComposeContent {
    makeButtonContent?(buttonState) ?? Empty()
  }

  private var makeButtonContent: ((ButtonState) -> ComposeContent)?
  private var onTap: (() -> Void)?
  var onDoubleTap: (() -> Void)?

  private lazy var pressGestureRecognizer = PressGestureRecognizer()

  override init(frame: CGRect) {
    super.init(frame: frame)

    pressGestureRecognizer.minimumPressDuration = 0
    pressGestureRecognizer.delegate = self
    #if canImport(UIKit)
    pressGestureRecognizer.addTarget(self, action: #selector(handlePress))
    #endif
    #if canImport(AppKit)
    pressGestureRecognizer.target = self
    pressGestureRecognizer.action = #selector(handlePress)
    #endif
    addGestureRecognizer(pressGestureRecognizer)

    clipsToBounds = false

    #if canImport(UIKit)
    isUserInteractionEnabled = true

    isAccessibilityElement = true
    accessibilityTraits = .button
    #endif
  }

  func configure(content: @escaping (ButtonState) -> ComposeContent, onTap: @escaping () -> Void) {
    makeButtonContent = content
    self.onTap = onTap

    setNeedsRefresh()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    #if canImport(UIKit)
    subviews.forEach { $0.isAccessibilityElement = false }
    #endif
  }

  // MARK: - Gesture

  ///  ===== Double Tap Mechanism =====
  ///
  ///  |---- delay ----|
  ///  |-------------------|
  /// down                 up
  ///                      single tap
  ///
  ///  First up is after the double-tap delay, then it's a single tap
  ///
  ///
  ///
  ///  |---- delay ----|
  ///  |------|
  /// down    up
  ///                  single tap
  ///
  ///  First up is before the double-tap delay, but no second down comes in time, then it's a single tap
  ///
  ///
  ///
  ///  |---- delay ----|
  ///  |------|    |-------|
  /// down    up  down     up
  ///                      double tap
  ///
  ///  First up is before the double-tap delay, and second down comes in time, then it's a double tap

  private var isDoubleTap: Bool = false

  @objc private func handlePress() {
    switch pressGestureRecognizer.state {
    case .possible:
      break

    case .began:
      // TODO: support cancel on move

      #if canImport(UIKit)
      guard !isOnDeceleratingScrollView else {
        // ignore the button press if the button is on a scroll view that is decelerating
        pressGestureRecognizer.cancel()
        return
      }
      #endif

      if onDoubleTap != nil {
        if doubleTapTimeoutTask != nil {
          // there's a double-tap timeout task, this means the second down is before the double-tap timeout
          // we should mark this session as a double tap
          isDoubleTap = true
          cancelDoubleTapTimeoutTask()
        } else {
          // there's no double-tap timeout task, this is the first down
          scheduleDoubleTapTimeoutTask()
        }
      }

      buttonState = .pressed

    case .changed:
      let point = pressGestureRecognizer.location(in: self)
      if bounds.inset(by: EdgeInsets(inset: -Constants.touchExpandedDistance)).contains(point) {
        buttonState = .pressed
      } else {
        buttonState = .normal
      }

    case .ended:
      let point = pressGestureRecognizer.location(in: self)
      guard bounds.inset(by: EdgeInsets(inset: -Constants.touchExpandedDistance)).contains(point) else {
        // press ended outside the button bounds
        reset()
        return
      }

      if onDoubleTap != nil {
        // double tap mode
        if isDoubleTap {
          // this is the second up, trigger double tap action
          reset()
          onDoubleTap?()
        } else {
          // this is the first up
          if doubleTapTimeoutTask != nil {
            // there's a double-tap timeout task, this means the first up is before the double-tap timeout
            // we should schedule the single tap action

            buttonState = .normal // reset button style before triggering actions
            doubleTapTimeoutBlock = { [weak self] in
              guard let self else {
                return
              }
              self.reset()
              self.onTap?()
            }
          } else {
            // there's no double-tap timeout task, this means the first up is after the double-tap timeout
            // we can trigger the single tap action directly
            reset()
            onTap?()
          }
        }
      } else {
        // single tap mode
        reset()
        onTap?()
      }

    case .cancelled,
         .failed:
      reset()

    @unknown default:
      reset()
    }
  }

  private func reset() {
    buttonState = .normal
    isDoubleTap = false
    cancelDoubleTapTimeoutTask()
  }

  // MARK: - Double-tap Delay

  private var doubleTapTimeoutTask: DispatchWorkItem?

  private var doubleTapTimeoutBlock: (() -> Void)?

  private func scheduleDoubleTapTimeoutTask() {
    doubleTapTimeoutTask?.cancel()

    let doubleTapTimeoutTask = DispatchWorkItem { [weak self] in
      guard let self = self else {
        return
      }

      self.doubleTapTimeoutTask = nil
      let block = self.doubleTapTimeoutBlock
      self.doubleTapTimeoutBlock = nil

      block?()
    }
    self.doubleTapTimeoutTask = doubleTapTimeoutTask

    DispatchQueue.main.asyncAfter(deadline: .now() + Constants.doubleTapTimeoutInterval, execute: doubleTapTimeoutTask)
  }

  private func cancelDoubleTapTimeoutTask() {
    guard doubleTapTimeoutTask != nil else {
      return
    }

    doubleTapTimeoutTask?.cancel()
    doubleTapTimeoutTask = nil
    doubleTapTimeoutBlock = nil
  }

  // MARK: - GestureRecognizerDelegate

  func gestureRecognizer(_ gestureRecognizer: GestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: GestureRecognizer) -> Bool {
    true
  }

  // MARK: - Constants

  private enum Constants {

    #if canImport(UIKit)
    /// The distance outside the button's bounds that the button will stay pressed.
    static let touchExpandedDistance: CGFloat = 60
    #elseif canImport(AppKit)
    static let touchExpandedDistance: CGFloat = 0
    #endif

    // TODO: configurable double tap interval

    /// The maximum time to wait for a second tap in a double-tap sequence.
    static var doubleTapTimeoutInterval: TimeInterval {
      #if canImport(UIKit)
      return 0.15
      #elseif canImport(AppKit)
      return NSEvent.doubleClickInterval
      #endif
    }
  }
}

#if canImport(UIKit)
private extension UIView {

  /// Whether the view is on a scroll view that is decelerating.
  var isOnDeceleratingScrollView: Bool {
    var parent = superview
    while let view = parent {
      if let scrollView = view as? ScrollView, scrollView.isDecelerating {
        return true
      }
      parent = view.superview
    }
    return false
  }
}
#endif
