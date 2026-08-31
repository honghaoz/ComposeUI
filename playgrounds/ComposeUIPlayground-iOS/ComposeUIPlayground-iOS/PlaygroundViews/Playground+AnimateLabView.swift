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
  /// The box is a plain sublayer outside of the render pass's management, animated only by the animate APIs. The toggle
  /// buttons drive a single animation each (immediate or with a 1s delay), and the scenario buttons run scripted
  /// sequences with fixed internal timings, so a session on one build can be compared with a session on another,
  /// visually and through the logged samples.
  ///
  /// Things to observe across builds:
  /// - A delayed animation shows the old value during the delay window, then animates.
  /// - When the model value changes relative to the visible change (the sample logs both).
  /// - How a delayed animation composes with an in-flight one, and the final resting values.
  final class AnimateLabView: ComposeView {

    private enum Constants {
      static let boxSize: CGFloat = 48
      static let boxMargin: CGFloat = 20
      static let duration: TimeInterval = 2.5
      static let delay: TimeInterval = 1
      static let fadedOpacity: Float = 0.15
      static let cornerRadiusNormal: CGFloat = 6
      static let cornerRadiusRounded: CGFloat = 24
    }

    /// The stage layer hosting the box. The box is positioned in the stage's coordinates once the stage has a size, and
    /// is otherwise fully owned by the animate calls.
    private let stageLayer = CALayer()

    private let boxLayer = CALayer()
    private var isBoxPositioned = false

    private var isMovedRight = false
    private var isFaded = false
    private var isRounded = false

    private var samplingTimer: Timer?
    private var lastSampleLine: String?

    private typealias Debug = Playground.Debug

    /// The time base for the logs: reset on every tap, so sample timestamps are relative to the last action and sessions
    /// from different builds can be compared line by line.
    private var referenceTime: CFTimeInterval = CACurrentMediaTime()

    /// Identifies the scenario run owning the scheduled steps, so a newer run cancels the older run's steps.
    private var scenarioToken = UUID()

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(spacing: 10) {
        LayerNode(
          make: { [weak self] _ in self?.stageLayer ?? CALayer() },
          update: { [weak self] _, context in
            self?.positionBoxIfNeeded(stageSize: context.newFrame.size)
          }
        )
        .underlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }
        .frame(width: .flexible, height: 100)

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

    private static func homeFrame(in stageBounds: CGRect) -> CGRect {
      CGRect(
        x: Constants.boxMargin,
        y: (stageBounds.height - Constants.boxSize) / 2,
        width: Constants.boxSize,
        height: Constants.boxSize
      )
    }

    /// Positions the box at its home frame once the stage has a size.
    private func positionBoxIfNeeded(stageSize: CGSize) {
      guard !isBoxPositioned, stageSize.width > 0 else {
        return
      }
      isBoxPositioned = true

      stageLayer.masksToBounds = true
      stageLayer.addSublayer(boxLayer)

      CATransaction.begin()
      CATransaction.setDisableActions(true)
      boxLayer.frame = Self.homeFrame(in: CGRect(origin: .zero, size: stageSize))
      boxLayer.backgroundColor = Colors.blueGray.cgColor
      boxLayer.cornerRadius = Constants.cornerRadiusNormal
      CATransaction.commit()
    }

    private func timing(delayed: Bool) -> AnimationTiming {
      .easeInEaseOut(duration: Constants.duration, delay: delayed ? Constants.delay : 0)
    }

    private func move(delayed: Bool) {
      isMovedRight.toggle()
      var targetFrame = Self.homeFrame(in: stageLayer.bounds)
      if isMovedRight {
        targetFrame.origin.x = stageLayer.bounds.width - Constants.boxSize - Constants.boxMargin
      }
      log("DISPATCH animateFrame(to: \(Debug.format(targetFrame.origin)), delay: \(delayed ? Constants.delay : 0))")
      boxLayer.animateFrame(to: targetFrame, timing: timing(delayed: delayed))
    }

    private func fade(delayed: Bool) {
      isFaded.toggle()
      let targetOpacity: Float = isFaded ? Constants.fadedOpacity : 1
      log("DISPATCH animate(opacity, to: \(Debug.format(targetOpacity)), delay: \(delayed ? Constants.delay : 0))")
      boxLayer.animate(keyPath: "opacity", to: targetOpacity, timing: timing(delayed: delayed))
    }

    private func corner(delayed: Bool) {
      isRounded.toggle()
      let targetRadius = isRounded ? Constants.cornerRadiusRounded : Constants.cornerRadiusNormal
      log("DISPATCH animate(cornerRadius, to: \(Debug.format(targetRadius)), delay: \(delayed ? Constants.delay : 0))")
      boxLayer.animate(keyPath: "cornerRadius", to: targetRadius, timing: timing(delayed: delayed))
    }

    /// Restores the box to its home state with no animations, so scenario runs start from the same state.
    private func reset() {
      scenarioToken = UUID()
      boxLayer.removeAllAnimations()
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      boxLayer.frame = Self.homeFrame(in: stageLayer.bounds)
      boxLayer.opacity = 1
      boxLayer.cornerRadius = Constants.cornerRadiusNormal
      CATransaction.commit()
      isMovedRight = false
      isFaded = false
      isRounded = false
      log("RESET")
    }

    // MARK: - Scenarios

    /// Resets the box, then runs the steps at their fixed offsets, logging each one.
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

    private func describeBox() -> String {
      let layer = boxLayer
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
