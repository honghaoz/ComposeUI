//
//  Playground+AnimateLabView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/27/26.
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

@_spi(Private) import ComposeUI

extension Playground {

  /// An interactive page for exercising the `CALayer` animate APIs directly.
  ///
  /// The stage hosts two boxes outside of the render pass's management, animated only by the animate APIs:
  /// - The top, blue-gray box is a plain `CALayer`.
  /// - The bottom, green box is a plain layer-backed `View`, driven through its backing layer. This additionally
  ///   exercises the animate APIs' `backedView` model sync (the view's `frame` on macOS and `alpha` on both platforms),
  ///   which a plain layer never hits.
  ///
  /// Every action dispatches the same animation to both boxes, so they should visibly move in lockstep. The toggle
  /// buttons drive a single animation each (immediate or with a 1s delay), and the scenario buttons run scripted
  /// sequences with fixed internal timings, so a session on one build can be compared with a session on another,
  /// visually and through the logged samples.
  ///
  /// Things to observe across builds:
  /// - A delayed animation shows the old value during the delay window, then animates.
  /// - When the model value changes relative to the visible change (the sample logs both).
  /// - How a delayed animation composes with an in-flight one, and the final resting values.
  /// - The view box stays in lockstep with the layer box, and its `frame`/`alpha` stay in sync with its layer's model
  ///   values (the view sample logs both).
  final class AnimateLabView: ComposeView {

    /// The stage view hosting the boxes. The boxes are positioned in the stage's coordinates once the stage has a size,
    /// and are otherwise fully owned by the animate calls. The stage is a view (not a layer) because the view box needs
    /// a view parent. `BaseView` is flipped on macOS, so both platforms use identical geometry.
    private let stageView = BaseView()

    /// The layer box, on the top lane.
    private let boxLayer = CALayer()

    /// The view box, on the bottom lane. Animated through its backing layer.
    private let boxView = BaseView()

    private var areBoxesPositioned = false

    private var isMovedRight = false
    private var isFaded = false
    private var isRounded = false

    private var samplingTimer: Timer?
    private var lastLayerSampleLine: String?
    private var lastViewSampleLine: String?

    private typealias Debug = Playground.Debug

    /// The time base for the logs: reset on every tap, so sample timestamps are relative to the last action and sessions
    /// from different builds can be compared line by line.
    private var referenceTime: CFTimeInterval = CACurrentMediaTime()

    /// Identifies the scenario run owning the scheduled steps, so a newer run cancels the older run's steps.
    private var scenarioToken = UUID()

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(spacing: 10) {
        ViewNode(
          make: { [weak self] _ in self?.stageView ?? BaseView() },
          update: { [weak self] _, context in
            self?.positionBoxesIfNeeded(stageSize: context.newFrame.size)
          }
        )
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .frame(width: .flexible, height: Constants.stageHeight)

        HStack(spacing: 10) {
          Playground.button(title: "Move ⇄", fontSize: 11) { [weak self] in
            self?.tap("Move") { self?.move(delayed: false) }
          }
          Playground.button(title: "Fade ⇄", fontSize: 11) { [weak self] in
            self?.tap("Fade") { self?.fade(delayed: false) }
          }
          Playground.button(title: "Corner ⇄", fontSize: 11) { [weak self] in
            self?.tap("Corner") { self?.corner(delayed: false) }
          }
        }
        .frame(width: .flexible, height: 32)

        HStack(spacing: 10) {
          Playground.button(title: "Move ⇄ +1s", fontSize: 11) { [weak self] in
            self?.tap("Move delayed") { self?.move(delayed: true) }
          }
          Playground.button(title: "Fade ⇄ +1s", fontSize: 11) { [weak self] in
            self?.tap("Fade delayed") { self?.fade(delayed: true) }
          }
          Playground.button(title: "Corner ⇄ +1s", fontSize: 11) { [weak self] in
            self?.tap("Corner delayed") { self?.corner(delayed: true) }
          }
        }
        .frame(width: .flexible, height: 32)

        HStack(spacing: 10) {
          Playground.button(title: "S1: fresh delayed move", fontSize: 11) { [weak self] in
            self?.runScenario("S1 fresh delayed move", steps: [
              (0, "move delayed", { self?.move(delayed: true) }),
            ])
          }
          Playground.button(title: "S2: interrupt in-flight", fontSize: 11) { [weak self] in
            self?.runScenario("S2 delayed move during in-flight move", steps: [
              (0, "move", { self?.move(delayed: false) }),
              (0.6, "move back delayed", { self?.move(delayed: true) }),
            ])
          }
        }
        .frame(width: .flexible, height: 32)

        HStack(spacing: 10) {
          Playground.button(title: "S3: two delayed moves", fontSize: 11) { [weak self] in
            self?.runScenario("S3 two overlapping delayed moves", steps: [
              (0, "move delayed", { self?.move(delayed: true) }),
              (0.4, "move back delayed", { self?.move(delayed: true) }),
            ])
          }
          Playground.button(title: "S4: stacked delayed fades", fontSize: 11) { [weak self] in
            self?.runScenario("S4 delayed fade during in-flight fade", steps: [
              (0, "fade", { self?.fade(delayed: false) }),
              (0.6, "fade back delayed", { self?.fade(delayed: true) }),
            ])
          }
        }
        .frame(width: .flexible, height: 32)

        Playground.button(title: "Reset", fontSize: 11) { [weak self] in
          self?.tap("Reset") { self?.reset() }
        }
        .frame(width: 120, height: 32)
      }
      .padding(12)
    }

    override init(frame: CGRect) {
      super.init(frame: frame)

      clippingBehavior = .always
    }

    // MARK: - Actions

    /// The view box's backing layer, which the animate calls drive.
    private var boxViewLayer: CALayer {
      #if canImport(AppKit)
      return boxView.layer! // swiftlint:disable:this force_unwrapping
      #else
      return boxView.layer
      #endif
    }

    /// The home frame for a lane, with lane 0 at the top. The lanes are vertically centered in the stage.
    private static func homeFrame(lane: Int, in stageBounds: CGRect) -> CGRect {
      let lanesHeight = Constants.boxSize * 2 + Constants.laneSpacing
      let topY = (stageBounds.height - lanesHeight) / 2
      return CGRect(
        x: Constants.boxMargin,
        y: topY + CGFloat(lane) * (Constants.boxSize + Constants.laneSpacing),
        width: Constants.boxSize,
        height: Constants.boxSize
      )
    }

    /// The target frame for a lane's box, based on the current moved state.
    private func targetFrame(lane: Int, in stageBounds: CGRect) -> CGRect {
      var frame = Self.homeFrame(lane: lane, in: stageBounds)
      if isMovedRight {
        frame.origin.x = stageBounds.width - Constants.boxSize - Constants.boxMargin
      }
      return frame
    }

    /// Positions the boxes at their home frames once the stage has a size.
    private func positionBoxesIfNeeded(stageSize: CGSize) {
      guard !areBoxesPositioned, stageSize.width > 0 else {
        return
      }
      areBoxesPositioned = true

      #if canImport(AppKit)
      let stageLayer = stageView.layer! // swiftlint:disable:this force_unwrapping
      #else
      let stageLayer = stageView.layer
      #endif
      stageLayer.masksToBounds = true
      stageLayer.addSublayer(boxLayer)
      stageView.addSubview(boxView)

      CATransaction.begin()
      CATransaction.setDisableActions(true)
      let stageBounds = CGRect(origin: .zero, size: stageSize)
      boxLayer.frame = Self.homeFrame(lane: 0, in: stageBounds)
      boxLayer.backgroundColor = Colors.blueGray.cgColor
      boxLayer.cornerRadius = Constants.cornerRadiusNormal

      boxView.frame = Self.homeFrame(lane: 1, in: stageBounds)
      boxViewLayer.backgroundColor = Colors.RetroApple.green.cgColor
      boxViewLayer.cornerRadius = Constants.cornerRadiusNormal

      Playground.addBoxNameLabel("layer", to: boxLayer, scale: Playground.displayScale(of: self))
      Playground.addBoxNameLabel("view", to: boxViewLayer, scale: Playground.displayScale(of: self))
      CATransaction.commit()
    }

    private func timing(delayed: Bool) -> AnimationTiming {
      .easeInEaseOut(duration: Constants.duration, delay: delayed ? Constants.delay : 0)
    }

    private func move(delayed: Bool) {
      isMovedRight.toggle()
      let stageBounds = stageView.bounds
      // the lanes share the same x, log it once for both boxes
      log("DISPATCH animateFrame(to x: \(Debug.format(targetFrame(lane: 0, in: stageBounds).origin.x)), delay: \(delayed ? Constants.delay : 0))")
      boxLayer.animateFrame(to: targetFrame(lane: 0, in: stageBounds), timing: timing(delayed: delayed))
      boxViewLayer.animateFrame(to: targetFrame(lane: 1, in: stageBounds), timing: timing(delayed: delayed))
    }

    private func fade(delayed: Bool) {
      isFaded.toggle()
      let targetOpacity: Float = isFaded ? Constants.fadedOpacity : 1
      log("DISPATCH animate(opacity, to: \(Debug.format(targetOpacity)), delay: \(delayed ? Constants.delay : 0))")
      boxLayer.animate(keyPath: "opacity", to: targetOpacity, timing: timing(delayed: delayed))
      boxViewLayer.animate(keyPath: "opacity", to: targetOpacity, timing: timing(delayed: delayed))
    }

    private func corner(delayed: Bool) {
      isRounded.toggle()
      let targetRadius = isRounded ? Constants.cornerRadiusRounded : Constants.cornerRadiusNormal
      log("DISPATCH animate(cornerRadius, to: \(Debug.format(targetRadius)), delay: \(delayed ? Constants.delay : 0))")
      boxLayer.animate(keyPath: "cornerRadius", to: targetRadius, timing: timing(delayed: delayed))
      boxViewLayer.animate(keyPath: "cornerRadius", to: targetRadius, timing: timing(delayed: delayed))
    }

    /// Restores the boxes to their home state with no animations, so scenario runs start from the same state.
    private func reset() {
      scenarioToken = UUID()
      boxLayer.removeAllAnimations()
      boxViewLayer.removeAllAnimations()
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      let stageBounds = stageView.bounds
      boxLayer.frame = Self.homeFrame(lane: 0, in: stageBounds)
      boxLayer.opacity = 1
      boxLayer.cornerRadius = Constants.cornerRadiusNormal

      // reset the view box through the view's properties so the view model and the layer stay in sync on macOS
      boxView.frame = Self.homeFrame(lane: 1, in: stageBounds)
      boxView.alpha = 1
      boxViewLayer.cornerRadius = Constants.cornerRadiusNormal
      CATransaction.commit()
      isMovedRight = false
      isFaded = false
      isRounded = false
      log("RESET")
    }

    // MARK: - Scenarios

    /// Resets the boxes, then runs the steps at their fixed offsets, logging each one.
    ///
    /// Starting a new scenario (or tapping any other button) cancels the previous scenario's remaining steps.
    private func runScenario(_ name: String, steps: [(offset: TimeInterval, name: String, action: () -> Void)]) {
      referenceTime = CACurrentMediaTime()
      log("SCENARIO \(name)")
      reset()

      let token = UUID()
      scenarioToken = token
      for step in steps {
        DispatchQueue.main.asyncAfter(deadline: .now() + step.offset) { [weak self] in
          guard let self, self.scenarioToken == token else {
            return
          }
          self.log("STEP \(step.name)")
          step.action()
        }
      }
    }

    /// Logs a tap and runs its action, cancelling any scenario in progress.
    private func tap(_ name: String, action: () -> Void) {
      referenceTime = CACurrentMediaTime()
      scenarioToken = UUID()
      log("TAP \(name)")
      action()
    }

    // MARK: - Constants

    private enum Constants {
      static let stageHeight: CGFloat = 120
      static let boxSize: CGFloat = 48
      static let boxMargin: CGFloat = 20
      static let laneSpacing: CGFloat = 8
      static let duration: TimeInterval = 2.5
      static let delay: TimeInterval = 1
      static let fadedOpacity: Float = 0.15
      static let cornerRadiusNormal: CGFloat = 6
      static let cornerRadiusRounded: CGFloat = 24
    }

    // MARK: - Sampling

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
        self?.sampleBoxStates()
      }
      RunLoop.main.add(timer, forMode: .common)
      samplingTimer = timer
    }

    /// Logs each box's state when it changed since the last sample.
    ///
    /// The boxes are sampled independently so a divergence between them shows up as one box logging without the other.
    /// The view box's sample includes the view's `frame` and `alpha`, which should track the layer's model values.
    private func sampleBoxStates() {
      let layerLine = describeBox(boxLayer)
      if layerLine != lastLayerSampleLine {
        lastLayerSampleLine = layerLine
        log("SAMPLE(layer) \(layerLine)")
      }

      let viewLine = "frame = \(Debug.format(boxView.frame)), alpha = \(Debug.format(boxView.alpha)), \(describeBox(boxViewLayer))"
      if viewLine != lastViewSampleLine {
        lastViewSampleLine = viewLine
        log("SAMPLE(view) \(viewLine)")
      }
    }

    private func describeBox(_ layer: CALayer) -> String {
      let model = "position = \(Debug.format(layer.position)), opacity = \(Debug.format(layer.opacity)), corner = \(Debug.format(layer.cornerRadius))"
      let presentation = layer.presentation().map {
        "presentation: position = \(Debug.format($0.position)), opacity = \(Debug.format($0.opacity)), corner = \(Debug.format($0.cornerRadius))"
      } ?? "presentation: nil"
      return "\(model), \(presentation), animations = \(Debug.describeAnimations(of: layer))"
    }

    private func log(_ message: String) {
      print("[AnimateLab] \(String(format: "+%.3f", CACurrentMediaTime() - referenceTime)) | \(message)")
    }
  }
}
