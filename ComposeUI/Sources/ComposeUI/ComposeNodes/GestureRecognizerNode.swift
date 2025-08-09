//
//  GestureRecognizerNode.swift
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

/// A node that can add gesture recognizers to a view.
private struct GestureRecognizerNode: ComposeNode {

  private var node: any ComposeNode
  private let handlers: [GestureRecognizerHandler]

  init(node: any ComposeNode, handler: GestureRecognizerHandler) {
    if let gestureRecognizerNode = node as? GestureRecognizerNode { // coalesce gesture recognizer nodes
      self.node = gestureRecognizerNode.node
      self.handlers = gestureRecognizerNode.handlers + [handler]
    } else {
      self.node = node
      self.handlers = [handler]
    }
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId = .standard(.gesture)

  var size: CGSize { node.size }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    node.layout(containerSize: containerSize, context: context)
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let childItems = node.renderableItems(in: visibleBounds)

    guard !childItems.isEmpty else {
      return []
    }

    let gestureOverlayViewItem = ViewItem<GestureView>(
      id: id,
      frame: CGRect(origin: .zero, size: size),
      make: { GestureView(frame: $0.initialFrame ?? .zero) },
      update: { view, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }
        view.updateGestureRecognizerHandlers(handlers)
      }
    )

    return childItems + [gestureOverlayViewItem.eraseToRenderableItem()]
  }
}

// MARK: - GestureRecognizerHandler

private struct GestureRecognizerHandler: Hashable {

  let handlerId = UUID()

  enum GestureRecognizerType: Hashable {
    case tap(count: Int)
    case press(duration: TimeInterval)
    case pan
  }

  let type: GestureRecognizerType
  let handler: (GestureRecognizer) -> Void

  func hash(into hasher: inout Hasher) {
    hasher.combine(handlerId)
  }

  static func == (lhs: GestureRecognizerHandler, rhs: GestureRecognizerHandler) -> Bool {
    lhs.handlerId == rhs.handlerId
  }
}

// MARK: - GestureView

/// An overlay view that hosts gesture recognizers.
private final class GestureView: BaseView, GestureRecognizerDelegate {

  private var installedGestureRecognizers: [GestureRecognizerHandler: GestureRecognizer] = [:]
  private var handlers: [GestureRecognizer: (GestureRecognizer) -> Void] = [:]

  func updateGestureRecognizerHandlers(_ newHandlers: [GestureRecognizerHandler]) {
    let oldHandlers = installedGestureRecognizers
    for (handler, recognizer) in oldHandlers {
      if !newHandlers.contains(handler) {
        // remove old handler
        removeGestureRecognizer(recognizer)
        installedGestureRecognizers.removeValue(forKey: handler)
        handlers.removeValue(forKey: recognizer)
      }
    }

    for handler in newHandlers {
      if installedGestureRecognizers[handler] == nil {
        // add new handler
        addGestureRecognizerHandler(handler)
      }
    }
  }

  private func addGestureRecognizerHandler(_ handler: GestureRecognizerHandler) {
    // make gesture recognizer
    let gestureRecognizer: GestureRecognizer
    switch handler.type {
    case .tap(let count):
      let tapGestureRecognizer = TapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
      #if canImport(UIKit)
      tapGestureRecognizer.numberOfTapsRequired = count
      #endif
      #if canImport(AppKit)
      tapGestureRecognizer.numberOfClicksRequired = count
      #endif
      gestureRecognizer = tapGestureRecognizer
    case .press(let duration):
      let pressGestureRecognizer = PressGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
      pressGestureRecognizer.minimumPressDuration = duration
      gestureRecognizer = pressGestureRecognizer
    case .pan:
      let panGestureRecognizer = PanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
      gestureRecognizer = panGestureRecognizer
    }

    #if canImport(UIKit)
    gestureRecognizer.cancelsTouchesInView = false
    #endif

    gestureRecognizer.delegate = self

    // install gesture recognizer
    addGestureRecognizer(gestureRecognizer)
    installedGestureRecognizers[handler] = gestureRecognizer
    handlers[gestureRecognizer] = handler.handler
  }

  @objc private func handleGesture(_ sender: GestureRecognizer) {
    handlers[sender]?(sender)
  }

  func gestureRecognizer(_ gestureRecognizer: GestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: GestureRecognizer) -> Bool {
    true
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Add a tap gesture with a handler.
  ///
  /// The node will return an overlay view that hosts and recognizes the tap gesture.
  ///
  /// - Parameters:
  ///   - count: The number of taps required to recognize the gesture.
  ///   - handler: The handler to call when the gesture is recognized.
  /// - Returns: A new node with the tap gesture added.
  func onTap(count: Int = 1, handler: @escaping (GestureRecognizer) -> Void) -> some ComposeNode {
    GestureRecognizerNode(node: self, handler: GestureRecognizerHandler(type: .tap(count: count), handler: handler))
  }

  /// Add a press gesture with a handler.
  ///
  /// The node will return an overlay view that hosts and recognizes the press gesture.
  ///
  /// - Parameters:
  ///   - duration: The minimum duration of the press to recognize the gesture. On macOS, this is the double-click interval. On UIKit devices, this is 0.5 seconds.
  ///   - handler: The handler to call when the gesture is recognized.
  /// - Returns: A new node with the press gesture added.
  func onPress(duration: TimeInterval = Constants.defaultPressDuration, handler: @escaping (GestureRecognizer) -> Void) -> some ComposeNode {
    GestureRecognizerNode(node: self, handler: GestureRecognizerHandler(type: .press(duration: duration), handler: handler))
  }

  /// Add a pan gesture with a handler.
  ///
  /// The node will return an overlay view that hosts and recognizes the pan gesture.
  ///
  /// - Parameters:
  ///   - handler: The handler to call when the gesture is recognized.
  /// - Returns: A new node with the pan gesture added.
  func onPan(handler: @escaping (GestureRecognizer) -> Void) -> some ComposeNode {
    GestureRecognizerNode(node: self, handler: GestureRecognizerHandler(type: .pan, handler: handler))
  }
}
