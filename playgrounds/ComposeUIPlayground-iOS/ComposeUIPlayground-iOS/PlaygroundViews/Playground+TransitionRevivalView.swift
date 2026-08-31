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
  /// The page inserts and removes two boxes together, so a revival is verified on both renderable kinds:
  /// - The top, blue-gray box is a layer renderable.
  /// - The bottom, green box is a view renderable, whose transitions additionally exercise the `backedView` model sync
  ///   (the view's `frame` on macOS and `alpha` on both platforms).
  ///
  /// The transitions run slowly so a removal can be interrupted mid-flight, and the transition button cycles through a
  /// fade, which retargets from the interrupted opacity, and two slide configurations, which continue the interrupted
  /// motion from wherever the removal left it and differ only in their entry and exit sides.
  /// A non-animated re-insert always snaps to the resting state.
  ///
  /// The page logs button taps, each box renderable's lifecycle events, and a continuous sample of each box layer's
  /// model and presentation values, so a manual test session can be diagnosed from the console output. The boxes are
  /// sampled independently, so a divergence between the layer box and the view box shows up as one box logging without
  /// the other.
  final class TransitionRevivalView: ComposeView {

    /// The transition to verify, cycled through by the page's transition button.
    private enum TransitionKind: CaseIterable {

      /// A fade, which retargets from the interrupted opacity on a revival.
      case opacity

      /// A slide that enters from the side it exits to, which continues the interrupted motion on a revival.
      case slide

      /// A slide that enters from a different side than it exits to. A revival continues the interrupted motion
      /// from the removal's model frame, so the box returns from wherever it is instead of restarting from the
      /// entry side.
      case crossSideSlide

      var title: String {
        switch self {
        case .opacity:
          return "opacity"
        case .slide:
          return "slide (left ⇄ left)"
        case .crossSideSlide:
          return "slide (left → right)"
        }
      }

      /// The animated property, for logging the relevant layer values.
      var animatesPosition: Bool {
        switch self {
        case .opacity:
          return false
        case .slide,
             .crossSideSlide:
          return true
        }
      }

      var transition: RenderableTransition {
        switch self {
        case .opacity:
          return .opacity(timing: .spring(dampingRatio: 0.8, response: 3))
        case .slide:
          return .slide(from: .left, timing: .easeInEaseOut(duration: 3))
        case .crossSideSlide:
          return .slide(from: .left, to: .right, timing: .easeInEaseOut(duration: 3))
        }
      }

      /// The next kind in the cycle.
      var next: TransitionKind {
        let kinds = Self.allCases
        // swiftlint:disable:next force_unwrapping
        let index = kinds.firstIndex(of: self)!
        return kinds[(index + 1) % kinds.count]
      }
    }

    private var isShowing = true
    private var transitionKind: TransitionKind = .opacity

    private weak var layerBoxLayer: CALayer?
    private weak var viewBoxView: View?
    private weak var viewBoxLayer: CALayer?
    private var samplingTimer: Timer?
    private var lastLayerSampleLine: String?
    private var lastViewSampleLine: String?

    private typealias Debug = Playground.Debug

    /// Whether the box layers can be tracked, which requires the content view's DEBUG-only debug events.
    private var isSamplingSupported: Bool {
      #if DEBUG
      return true
      #else
      return false
      #endif
    }

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(spacing: 12) {
        VStack(spacing: Constants.laneSpacing) {
          if isShowing {
            // the layer lane: the transition drives a plain layer renderable.
            // the box's name is a sublayer (instead of an overlay node) so the box stays a single renderable for the
            // lifecycle logging, and the name rides along during transitions.
            LayerNode(
              update: { [weak self] layer, _ in
                guard let self else {
                  return
                }
                layer.backgroundColor = Colors.blueGray.cgColor
                Playground.addBoxNameLabel("layer", to: layer, scale: Playground.displayScale(of: self))
              }
            )
            .transition(transitionKind.transition)
            .frame(Constants.boxSize)
            .id("layer-box")

            // the view lane: the transition drives a view renderable, which additionally exercises the view model sync
            // (frame/alpha)
            ViewNode<BaseView>(
              update: { [weak self] view, _ in
                guard let self else {
                  return
                }
                #if canImport(AppKit)
                let boxLayer = view.layer! // swiftlint:disable:this force_unwrapping
                #else
                let boxLayer = view.layer
                #endif
                boxLayer.backgroundColor = Colors.RetroApple.green.cgColor
                Playground.addBoxNameLabel("view", to: boxLayer, scale: Playground.displayScale(of: self))
              }
            )
            .transition(transitionKind.transition)
            .frame(Constants.boxSize)
            .id("view-box")
          } else {
            Empty()
          }
        }
        .frame(width: .flexible, height: .flexible)

        HStack(spacing: 12) {
          // 14pt so the longest title, "Remove (animated)", fits the half-width button on compact screens
          Playground.button(title: isShowing ? "Remove (animated)" : "Insert (animated)", fontSize: 14) { [weak self] in
            guard let self else {
              return
            }
            self.isShowing.toggle()
            self.log("TAP \(self.isShowing ? "Insert" : "Remove") (animated), isShowing -> \(self.isShowing)")
            self.refresh(animated: true)
            self.logBoxState("after refresh(animated: true)")
          }

          Playground.button(title: isShowing ? "Remove (instant)" : "Insert (instant)", fontSize: 14) { [weak self] in
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

        Playground.button(title: "Transition: \(transitionKind.title)", fontSize: 14) { [weak self] in
          guard let self else {
            return
          }
          self.transitionKind = self.transitionKind.next
          self.log("TAP transition kind -> \(self.transitionKind.title)")
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
      let id = item.id.id
      if id.contains("layer-box") {
        layerBoxLayer = renderable.layer
        log("EVENT(layer) \(name), \(describeLayerBox())")
      } else if id.contains("view-box") {
        viewBoxView = renderable.view
        viewBoxLayer = renderable.layer
        log("EVENT(view) \(name), \(describeViewBox())")
      }
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

    // MARK: - Constants

    private enum Constants {

      /// The size of each box lane.
      static let boxSize = CGSize(width: 160, height: 64)

      /// The spacing between the two box lanes.
      static let laneSpacing: CGFloat = 8
    }

    // MARK: - Sampling

    /// Runs the sampling timer while the view is in a window.
    ///
    /// The box layers are tracked through the content view's debug events, which are DEBUG-only, so sampling only has
    /// something to report in a DEBUG build.
    private func updateSampling() {
      guard isSamplingSupported, window != nil else {
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

    /// Logs each box's state when it changed since the last sample.
    private func sampleBoxState() {
      let layerLine = describeLayerBox()
      if layerLine != lastLayerSampleLine {
        lastLayerSampleLine = layerLine
        log("SAMPLE(layer) \(layerLine)")
      }

      let viewLine = describeViewBox()
      if viewLine != lastViewSampleLine {
        lastViewSampleLine = viewLine
        log("SAMPLE(view) \(viewLine)")
      }
    }

    private func logBoxState(_ label: String) {
      log("STATE(layer) (\(label)) \(describeLayerBox())")
      log("STATE(view) (\(label)) \(describeViewBox())")
    }

    private func describeLayerBox() -> String {
      describeBox(layer: layerBoxLayer)
    }

    /// Describes the view box: the view's model values (which should track its layer's model values), then the layer.
    private func describeViewBox() -> String {
      guard let view = viewBoxView else {
        return "box view = nil"
      }
      let viewModel: String
      if transitionKind.animatesPosition {
        viewModel = "viewFrame = \(Debug.format(view.frame))"
      } else {
        viewModel = "viewAlpha = \(Debug.format(view.alpha))"
      }
      return "\(viewModel), \(describeBox(layer: viewBoxLayer))"
    }

    private func describeBox(layer: CALayer?) -> String {
      guard let layer else {
        return "box layer = nil"
      }
      let pointer = String(describing: Unmanaged.passUnretained(layer).toOpaque())
      let model: String
      let presentation: String
      if transitionKind.animatesPosition {
        model = "position = \(Debug.format(layer.position))"
        presentation = "presentationPosition = \(layer.presentation().map { Debug.format($0.position) } ?? "nil")"
      } else {
        model = "opacity = \(Debug.format(layer.opacity))"
        presentation = "presentationOpacity = \(layer.presentation().map { Debug.format($0.opacity) } ?? "nil")"
      }
      let inTree = layer.superlayer != nil ? "attached" : "DETACHED"
      return "layer = \(pointer) (\(inTree)), \(model), \(presentation), animations = \(Debug.describeAnimations(of: layer))"
    }

    private func log(_ message: String) {
      print("[Revival] \(String(format: "%.3f", CACurrentMediaTime())) | \(message)")
    }
  }
}
