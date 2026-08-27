//
//  AdditiveOpacityDemoWindow.swift
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

import AppKit
import QuartzCore

/// A pure Core Animation demo window that reproduces the additive opacity composition issue
/// without any ComposeUI code.
///
/// "Fade In" and "Fade Out" stack additive opacity animations using the same recipe as a
/// transition: write the model value to the target, then add an additive animation that decays
/// the delta to zero. Interrupting one fade with the other makes the on-screen opacity diverge
/// from the unclamped additive sum reported by `presentation()`, because the render server
/// clamps opacity while compositing the additive animations.
final class AdditiveOpacityDemoWindow: NSWindowController {

  private let boxLayer = CALayer()
  private let statusLabel = NSTextField(labelWithString: "")
  private var animationCount = 0
  private var samplingTimer: Timer?
  private var lastSampleLine: String?

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Additive Opacity (pure Core Animation)"
    self.init(window: window)

    let contentView = NSView(frame: window.contentLayoutRect)
    contentView.autoresizingMask = [.width, .height]
    contentView.wantsLayer = true
    window.contentView = contentView

    boxLayer.backgroundColor = NSColor.systemRed.cgColor
    boxLayer.frame = CGRect(x: 160, y: 160, width: 100, height: 100)
    boxLayer.opacity = 1
    contentView.layer?.addSublayer(boxLayer)

    let fadeInButton = NSButton(title: "Fade In (additive)", target: self, action: #selector(fadeIn))
    let fadeOutButton = NSButton(title: "Fade Out (additive)", target: self, action: #selector(fadeOut))
    let resetButton = NSButton(title: "Reset", target: self, action: #selector(reset))

    let buttons = NSStackView(views: [fadeInButton, fadeOutButton, resetButton])
    buttons.orientation = .horizontal
    buttons.spacing = 8
    buttons.frame = NSRect(x: 20, y: 80, width: 380, height: 32)
    buttons.autoresizingMask = [.width]
    contentView.addSubview(buttons)

    statusLabel.frame = NSRect(x: 20, y: 20, width: 380, height: 48)
    statusLabel.autoresizingMask = [.width]
    statusLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
    statusLabel.maximumNumberOfLines = 3
    contentView.addSubview(statusLabel)

    let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      self?.sample()
    }
    RunLoop.main.add(timer, forMode: .common)
    samplingTimer = timer
  }

  deinit {
    samplingTimer?.invalidate()
  }

  /// Mirrors an insert transition: model to 1, additive animation from -1 to 0.
  @objc
  private func fadeIn() {
    log("TAP Fade In")
    addAdditiveOpacityAnimation(targetModelValue: 1)
  }

  /// Mirrors a remove transition: model to 0, additive animation from the current model value to 0.
  @objc
  private func fadeOut() {
    log("TAP Fade Out")
    addAdditiveOpacityAnimation(targetModelValue: 0)
  }

  @objc
  private func reset() {
    log("TAP Reset")
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    boxLayer.removeAllAnimations()
    boxLayer.opacity = 1
    CATransaction.commit()
    animationCount = 0
  }

  /// Writes the model value to the target and stacks an additive animation that decays the old
  /// delta to zero. Existing animations are kept, exactly like stacked additive transitions.
  private func addAdditiveOpacityAnimation(targetModelValue: Float) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    let delta = boxLayer.opacity - targetModelValue

    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = delta
    animation.toValue = 0
    animation.duration = 5
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    animation.isAdditive = true

    animationCount += 1
    boxLayer.add(animation, forKey: "opacity-\(animationCount)")
    boxLayer.opacity = targetModelValue

    CATransaction.commit()

    log("added additive \(String(format: "%.3f", delta)) -> 0, model -> \(targetModelValue), \(describeAnimations())")
  }

  private func sample() {
    let line = "model = \(String(format: "%.3f", boxLayer.opacity)), presentation() = \(boxLayer.presentation().map { String(format: "%.3f", $0.opacity) } ?? "nil"), \(describeAnimations())"
    statusLabel.stringValue = "Screen shows the box. Compare with:\n\(line)"
    guard line != lastSampleLine else {
      return
    }
    lastSampleLine = line
    log("SAMPLE \(line)")
  }

  private func describeAnimations() -> String {
    let keys = boxLayer.animationKeys() ?? []
    let now = CACurrentMediaTime()
    let descriptions = keys.compactMap { key -> String? in
      guard let animation = boxLayer.animation(forKey: key) as? CABasicAnimation else {
        return nil
      }
      let from = (animation.fromValue as? NSNumber).map { String(format: "%.3f", $0.doubleValue) } ?? "nil"
      return "\(key): \(from) -> 0, elapsed = \(String(format: "%.2f", now - animation.beginTime))/\(String(format: "%.0f", animation.duration))s"
    }
    return "animations = [\(descriptions.joined(separator: " | "))]"
  }

  private func log(_ message: String) {
    print("[CAOpacityDemo] \(String(format: "%.3f", CACurrentMediaTime())) | \(message)")
  }
}
