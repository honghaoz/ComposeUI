//
//  ButtonView.swift
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

/// A button view.
open class ButtonView: ComposeView, GestureRecognizerDelegate {

  /// The current state of the button.
  private var buttonState: ButtonState = .normal {
    didSet {
      if buttonState != oldValue {
        refresh()
      }
    }
  }

  /// The content of the button.
  override public final var content: ComposeContent {
    makeButtonContent?(buttonState, self) ?? Empty()
  }

  private var makeButtonContent: ((ButtonState, ComposeView) -> ComposeContent)?
  private var onTap: (() -> Void)?

  /// The handler to be called when the button is double tapped.
  ///
  /// The default value is `nil`.
  /// If this value is set, the button's single tap action will be slightly delayed to detect double taps.
  public var onDoubleTap: (() -> Void)?

  /// The override double tap interval.
  ///
  /// The default value is `nil`.
  /// When the value is `nil`, for UIKit, the duration is `0.15` seconds, for AppKit, the duration is `NSEvent.doubleClickInterval`.
  public var doubleTapInterval: TimeInterval?

  private lazy var pressGestureRecognizer = PressGestureRecognizer()

  override public init(frame: CGRect) {
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
    #endif

    #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
    hapticFeedbackGenerator = makeHapticFeedbackGenerator(style: hapticFeedbackStyle)
    #endif

    #if canImport(UIKit)
    isAccessibilityElement = true
    accessibilityTraits = .button
    #endif
    #if canImport(AppKit)
    setAccessibilityElement(true)
    setAccessibilityRole(.button)
    #endif
  }

  /// Configure the button with a content provider with handlers.
  ///
  /// - Parameters:
  ///   - content: The content provider for different button states.
  ///   - onTap: The handler to be called when the button is tapped.
  ///   - onDoubleTap: The handler to be called when the button is double tapped. Default is `nil`.
  public func configure(content: @escaping (ButtonState, ComposeView) -> ComposeContent,
                        onTap: @escaping () -> Void,
                        onDoubleTap: (() -> Void)? = nil)
  {
    makeButtonContent = content
    self.onTap = onTap
    self.onDoubleTap = onDoubleTap

    setNeedsRefresh()
  }

  override public func layoutSubviews() {
    super.layoutSubviews()

    #if canImport(UIKit)
    subviews.forEach { $0.isAccessibilityElement = false }
    #endif
    #if canImport(AppKit)
    subviews.forEach { $0.setAccessibilityElement(false) }
    #endif
  }

  // MARK: - Gesture Handling

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
    _handlePress(with: pressGestureRecognizer)
  }

  private func _handlePress(with pressGestureRecognizer: PressGestureRecognizerType) {
    switch pressGestureRecognizer.state {
    case .possible:
      break

    case .began:
      #if canImport(UIKit)
      guard !isOnScrollingScrollView else {
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

      #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
      hapticFeedbackGenerator?.prepare()
      #endif

    case .changed:
      #if canImport(UIKit)
      guard !isOnScrollingScrollView else {
        // cancel the button press if the button is on a scroll view that is scrolling
        pressGestureRecognizer.cancel()
        return
      }
      #endif

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
          triggerHapticFeedback()
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
              self.triggerHapticFeedback()
              self.onTap?()
            }
          } else {
            // there's no double-tap timeout task, this means the first up is after the double-tap timeout
            // we can trigger the single tap action directly
            reset()
            triggerHapticFeedback()
            onTap?()
          }
        }
      } else {
        // single tap mode
        reset()
        triggerHapticFeedback()
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

    DispatchQueue.main.asyncAfter(
      deadline: .now() + (doubleTapInterval ?? ComposeUI.Constants.defaultDoubleTapDuration),
      execute: doubleTapTimeoutTask
    )
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

  public func gestureRecognizer(_ gestureRecognizer: GestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: GestureRecognizer) -> Bool {
    true
  }

  // MARK: - Haptic Feedback

  #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
  /// The style of haptic feedback to be used when the button is pressed.
  ///
  /// The default value is `.light`.
  public var hapticFeedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle? = .light {
    didSet {
      if hapticFeedbackStyle != oldValue {
        hapticFeedbackGenerator = makeHapticFeedbackGenerator(style: hapticFeedbackStyle)
      }
    }
  }

  private var hapticFeedbackGenerator: UIImpactFeedbackGenerator?

  private func makeHapticFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle?) -> UIImpactFeedbackGenerator? {
    guard let style else {
      return nil
    }

    if #available(iOS 17.5, *) {
      return UIImpactFeedbackGenerator(style: style, view: self)
    } else {
      return UIImpactFeedbackGenerator(style: style)
    }
  }
  #endif

  private func triggerHapticFeedback() {
    #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
    hapticFeedbackGenerator?.impactOccurred(intensity: 0.75)
    #endif
  }

  #if canImport(AppKit)

  // MARK: - Key Equivalent

  /// A closure that determines whether the button should perform a key equivalent.
  ///
  /// The default value is `nil`.
  ///
  /// If this value is set, the button will simulate a button press when the closure returns `true`.
  ///
  /// - Note: Long press key equivalent will trigger multiple button presses.
  public var shouldPerformKeyEquivalent: ((NSEvent) -> Bool)?

  override open func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard let shouldPerformKeyEquivalent = shouldPerformKeyEquivalent, shouldPerformKeyEquivalent(event) else {
      return super.performKeyEquivalent(with: event)
    }

    // simulate a button press
    let pressGestureRecognizer = PressGestureRecognizerMock()
    pressGestureRecognizer.state = .began
    _handlePress(with: pressGestureRecognizer)

    RunLoop.main.perform { // delay to make sure the button UI can be updated
      pressGestureRecognizer.state = .ended
      self._handlePress(with: pressGestureRecognizer)
    }

    return true
  }
  #endif

  // MARK: - Accessibility

  #if canImport(AppKit)
  override open func accessibilityPerformPress() -> Bool {
    onTap?()
    return true
  }
  #endif

  // MARK: - Constants

  private enum Constants {

    #if canImport(UIKit)
    /// The distance outside the button's bounds that the button will stay pressed.
    static let touchExpandedDistance: CGFloat = 60
    #elseif canImport(AppKit)
    static let touchExpandedDistance: CGFloat = 0
    #endif
  }

  // MARK: - Testing

  #if DEBUG
  var buttonTest: ButtonViewTest { ButtonViewTest(host: self) }

  class ButtonViewTest {

    private let host: ButtonView

    fileprivate init(host: ButtonView) {
      ComposeUI.assert(Thread.isRunningXCTest, "Test namespace should only be used in test target.")
      self.host = host
    }

    var buttonState: ButtonState {
      host.buttonState
    }

    var pressGestureRecognizer: PressGestureRecognizer {
      host.pressGestureRecognizer
    }

    func press() {
      host.handlePress()
    }
  }
  #endif
}

#if canImport(UIKit)
private extension UIView {

  /// Whether the view is on a scroll view that is scrolling (dragging or decelerating)
  var isOnScrollingScrollView: Bool {
    var parent = superview
    while let view = parent {
      if let scrollView = view as? ScrollView,
         scrollView.isDragging || scrollView.isDecelerating
      {
        return true
      }
      parent = view.superview
    }
    return false
  }
}
#endif

// MARK: - PressGestureRecognizerType

/// A protocol that represents a press gesture recognizer.
private protocol PressGestureRecognizerType {

  var state: GestureRecognizer.State { get }

  func location(in view: View?) -> CGPoint
  func cancel()
}

extension PressGestureRecognizer: PressGestureRecognizerType {}

/// A mock press gesture recognizer.
private class PressGestureRecognizerMock: PressGestureRecognizerType {

  var state: GestureRecognizer.State = .possible

  func location(in view: View?) -> CGPoint {
    guard let view else {
      return .zero
    }
    return CGPoint(x: view.bounds.midX, y: view.bounds.midY)
  }

  func cancel() {}
}
