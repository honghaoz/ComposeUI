//
//  PausedLayerRenderer.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/25/26.
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

#if os(macOS)

import Metal
import QuartzCore
import XCTest

/// Renders a white layer over black through `CARenderer` on a paused timeline, to read the opacity that shows on
/// screen, which `presentation()` doesn't report for stacked opacity animations.
///
/// The layers' time is the paused root layer's time offset, set with `move(to:)`.
final class PausedLayerRenderer {

  /// The white layer to render, filling the root layer.
  let layer: CALayer

  private let rootLayer: CALayer
  private let texture: MTLTexture
  private let commandQueue: MTLCommandQueue
  private let renderer: CARenderer

  /// Creates a renderer with its timeline paused at the given time. Throws `XCTSkip` without a Metal device.
  ///
  /// - Parameter time: The time to pause the timeline at.
  init(time: CFTimeInterval) throws {
    guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
      throw XCTSkip("rendering through CARenderer requires a Metal device")
    }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 4, height: 4, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    self.texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
    self.commandQueue = commandQueue

    rootLayer = CALayer()
    rootLayer.frame = CGRect(x: 0, y: 0, width: 4, height: 4)
    rootLayer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    rootLayer.speed = 0
    rootLayer.timeOffset = time

    layer = CALayer()
    layer.frame = rootLayer.bounds
    layer.backgroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    rootLayer.addSublayer(layer)

    renderer = CARenderer(mtlTexture: texture, options: [kCARendererMetalCommandQueue: commandQueue])
    renderer.layer = rootLayer
    renderer.bounds = rootLayer.bounds

    commit()
  }

  /// Moves the paused timeline to the given time.
  func move(to time: CFTimeInterval) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    rootLayer.timeOffset = time
    CATransaction.commit()
    commit()
  }

  /// Commits the pending changes, which starts the animations added since at the current time.
  func commit() {
    CATransaction.flush()
  }

  /// The opacity the white layer shows at the current time.
  func renderedOpacity() -> Double {
    commit()

    renderer.beginFrame(atTime: CACurrentMediaTime(), timeStamp: nil)
    renderer.addUpdate(renderer.bounds)
    renderer.render()
    renderer.endFrame()

    // a command buffer committed after the renderer's work on the same queue completes after it
    let fence = commandQueue.makeCommandBuffer()
    fence?.commit()
    fence?.waitUntilCompleted()

    var pixel = [UInt8](repeating: 0, count: 4)
    texture.getBytes(&pixel, bytesPerRow: 16, from: MTLRegionMake2D(1, 1, 1, 1), mipmapLevel: 0)
    return Double(pixel[2]) / 255 // BGRA: the red channel
  }
}

#endif
