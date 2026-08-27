//
//  Playground+TransitionRevivalView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/26/26.
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

import ComposeUI

extension Playground {

  /// An interactive insert/remove page for verifying transition revivals.
  ///
  /// The transitions run slowly so a removal can be interrupted mid-flight: an animated re-insert
  /// reverses from the current visual state, a non-animated re-insert snaps to the resting state.
  ///
  /// The page logs button taps, the box renderable's lifecycle events, and a continuous sample of
  /// the box layer's model and presentation values, so a manual test session can be diagnosed from
  /// the console output.
  final class TransitionRevivalView: ComposeView {

    private var isShowing = true
    private var usesSlide = false

    private weak var boxLayer: CALayer?
    private var samplingTimer: Timer?
    private var lastSampleLine: String?

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(spacing: 12) {
        VStack {
          if isShowing {
            ColorNode(Colors.blueGray)
              .transition(
                usesSlide
                  ? .slide(from: .left, timing: .easeInEaseOut(duration: 3))
                  : .opacity(timing: .spring(dampingRatio: 0.8, response: 3))
              )
              .frame(width: 160, height: 64)
              .id("box")
              .frame(.flexible, alignment: .center)
          } else {
            Empty()
          }
        }
        .frame(width: .flexible, height: .flexible)

        HStack(spacing: 12) {
          button(title: isShowing ? "Remove (animated)" : "Insert (animated)") { [weak self] in
            guard let self else {
              return
            }
            self.isShowing.toggle()
            self.log("TAP \(self.isShowing ? "Insert" : "Remove") (animated), isShowing -> \(self.isShowing)")
            self.refresh(animated: true)
            self.logBoxState("after refresh(animated: true)")
          }

          button(title: isShowing ? "Remove (instant)" : "Insert (instant)") { [weak self] in
            guard let self else {
              return
            }
            self.isShowing.toggle()
            self.log("TAP \(self.isShowing ? "Insert" : "Remove") (instant), isShowing -> \(self.isShowing)")
            self.refresh(animated: false)
            self.logBoxState("after refresh(animated: false)")
          }
        }
        .frame(width: .flexible, height: 36)

        button(title: usesSlide ? "Transition: slide" : "Transition: opacity") { [weak self] in
          guard let self else {
            return
          }
          self.usesSlide.toggle()
          self.log("TAP transition kind -> \(self.usesSlide ? "slide" : "opacity")")
          self.refresh(animated: false)
        }
        .frame(width: .flexible, height: 36)
      }
      .padding(12)
    }

    override init(frame: CGRect) {
      super.init(frame: frame)

      clippingBehavior = .always

      #if DEBUG
      debug { [weak self] _, event in
        self?.handleDebugEvent(event)
      }
      #endif
    }

    // MARK: - Debug Logging

    #if DEBUG
    private func handleDebugEvent(_ event: ComposeView.Debug.Event) {
      switch event {
      case .renderWillInsertRenderable(let item, let renderable):
        logBoxEvent("willInsert", item: item, renderable: renderable)
      case .renderDidInsertRenderable(let item, let renderable):
        logBoxEvent("didInsert", item: item, renderable: renderable)
      case .renderWillReuseRenderable(let item, let renderable):
        logBoxEvent("willReuse", item: item, renderable: renderable)
      case .renderWillRemoveRenderable(let item, let renderable):
        logBoxEvent("willRemove", item: item, renderable: renderable)
      case .renderDidRemoveRenderable(let item, let renderable):
        logBoxEvent("didRemove", item: item, renderable: renderable)
      case .renderDidCancelRemoveRenderable(let item, let renderable):
        logBoxEvent("cancelRemove (revive)", item: item, renderable: renderable)
      default:
        break
      }
    }

    private func logBoxEvent(_ name: String, item: RenderableItem, renderable: Renderable) {
      guard item.id.id.contains("box") else {
        return
      }
      boxLayer = renderable.layer
      log("EVENT \(name), \(describeBox())")
    }
    #endif

    #if canImport(UIKit)
    override func didMoveToWindow() {
      super.didMoveToWindow()
      updateSampling()
    }
    #endif

    #if canImport(AppKit)
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      updateSampling()
    }
    #endif

    deinit {
      samplingTimer?.invalidate()
    }

    /// Runs the sampling timer while the view is in a window.
    private func updateSampling() {
      guard window != nil else {
        samplingTimer?.invalidate()
        samplingTimer = nil
        return
      }
      guard samplingTimer == nil else {
        return
      }
      let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
        self?.sampleBoxState()
      }
      RunLoop.main.add(timer, forMode: .common)
      samplingTimer = timer
    }

    /// Logs the box layer's state when it changed since the last sample.
    private func sampleBoxState() {
      let line = describeBox()
      guard line != lastSampleLine else {
        return
      }
      lastSampleLine = line
      log("SAMPLE \(line)")
    }

    private func logBoxState(_ label: String) {
      log("STATE (\(label)) \(describeBox())")
    }

    private func describeBox() -> String {
      guard let layer = boxLayer else {
        return "box layer = nil"
      }
      let pointer = String(describing: Unmanaged.passUnretained(layer).toOpaque())
      let model: String
      let presentation: String
      if usesSlide {
        model = "position = \(format(layer.position))"
        presentation = "presentationPosition = \(layer.presentation().map { format($0.position) } ?? "nil")"
      } else {
        model = "opacity = \(format(layer.opacity))"
        presentation = "presentationOpacity = \(layer.presentation().map { format($0.opacity) } ?? "nil")"
      }
      let inTree = layer.superlayer != nil ? "attached" : "DETACHED"
      return "layer = \(pointer) (\(inTree)), \(model), \(presentation), animations = \(describeAnimations(of: layer))"
    }

    private func describeAnimations(of layer: CALayer) -> String {
      let keys = layer.animationKeys() ?? []
      guard !keys.isEmpty else {
        return "[]"
      }
      let now = layer.convertTime(CACurrentMediaTime(), from: nil)
      let descriptions = keys.map { key -> String in
        guard let animation = layer.animation(forKey: key) as? CABasicAnimation else {
          return "\(key): \(type(of: layer.animation(forKey: key) as Any))"
        }
        let from = describeValue(animation.fromValue)
        let to = describeValue(animation.toValue)
        let elapsed = now - animation.beginTime
        return "\(key)(\(animation.keyPath ?? "?")): \(from) -> \(to)\(animation.isAdditive ? " additive" : ""), elapsed = \(format(elapsed))/\(format(animation.duration))s"
      }
      return "[\(descriptions.joined(separator: " | "))]"
    }

    private func describeValue(_ value: Any?) -> String {
      switch value {
      case let number as NSNumber:
        return format(number.doubleValue)
      case let point as NSValue:
        #if canImport(UIKit)
        return format(point.cgPointValue)
        #else
        return format(point.pointValue)
        #endif
      case .none:
        return "nil"
      case .some(let other):
        return String(describing: other)
      }
    }

    private func format(_ value: Double) -> String {
      String(format: "%.3f", value)
    }

    private func format(_ value: Float) -> String {
      String(format: "%.3f", value)
    }

    private func format(_ value: CGFloat) -> String {
      String(format: "%.3f", value)
    }

    private func format(_ point: CGPoint) -> String {
      String(format: "(%.1f, %.1f)", point.x, point.y)
    }

    private func log(_ message: String) {
      print("[Revival] \(String(format: "%.3f", CACurrentMediaTime())) | \(message)")
    }

    private func button(title: String, onTap: @escaping () -> Void) -> ComposeNode {
      ButtonNode(
        content: { state in
          let backgroundColor: Color
          switch state {
          case .normal,
               .hovered:
            backgroundColor = Colors.blueGray
          case .pressed,
               .selected:
            backgroundColor = Colors.darkBlueGray
          case .disabled:
            backgroundColor = Colors.lightBlueGray
          }
          ColorNode(backgroundColor)
            .cornerRadius(6)
            .overlay {
              Label(title)
                .textColor(.white)
                .selectable(false)
            }
        },
        onTap: onTap
      )
    }
  }
}
