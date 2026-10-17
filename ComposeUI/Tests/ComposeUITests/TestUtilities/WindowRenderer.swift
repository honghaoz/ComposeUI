//
//  WindowRenderer.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/16/26.
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
import Metal
import XCTest

/// A window with a view to render through `CARenderer`, which shows the pixels that the window shows, including the
/// contents that AppKit draws for a layer-backed view, which `CALayer.render(in:)` draws again instead.
final class WindowRenderer {

  /// A window whose backing store has a scale that a test sets, instead of the scale of the machine's screen, so the
  /// pixels are the same on each machine.
  final class Window: NSWindow {

    /// The scale of the window's backing store, which a screen of the scale gives it.
    var scale: CGFloat

    override var backingScaleFactor: CGFloat {
      scale
    }

    init(scale: CGFloat) {
      self.scale = scale
      super.init(contentRect: CGRect(x: 0, y: 0, width: 500, height: 500), styleMask: [.closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
      contentView?.wantsLayer = true
    }
  }

  /// The window, in the light appearance.
  let window: Window

  /// The view to render, which renders its subviews at the window's scale, one pixel of their contents to one pixel.
  let view: NSView

  private let commandQueue: MTLCommandQueue

  /// Creates a window with a view of a size to render. Throws `XCTSkip` without a Metal device.
  ///
  /// - Parameters:
  ///   - size: The size of the view to render.
  ///   - scale: The scale of the window's backing store. The default is 2, the scale of a Retina screen.
  init(size: CGSize, scale: CGFloat = 2) throws {
    guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
      throw XCTSkip("rendering through CARenderer requires a Metal device")
    }
    self.commandQueue = commandQueue

    window = Window(scale: scale)
    window.appearance = NSAppearance(named: .aqua)
    view = NSView(frame: CGRect(origin: .zero, size: size))
    view.wantsLayer = true
    window.contentView?.addSubview(view)
  }

  /// Returns the pixels that the window shows for the view, one for each pixel of the window's backing store.
  ///
  /// - Parameter time: The time to render the animations at, the current time by default.
  /// - Returns: The pixels.
  func render(at time: CFTimeInterval? = nil) throws -> RenderedPixels {
    window.displayIfNeeded()

    let scale = window.backingScaleFactor
    let width = Int((view.bounds.width * scale).rounded(.up))
    let height = Int((view.bounds.height * scale).rounded(.up))
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try XCTUnwrap(commandQueue.device.makeTexture(descriptor: descriptor))

    // the renderer maps the layer's points to the texture's pixels one to one, so the view's layer scales its sublayers
    // to show their contents one pixel to one pixel
    let layer = try XCTUnwrap(view.layer)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1)
    CATransaction.commit()

    let renderer = CARenderer(mtlTexture: texture, options: [kCARendererMetalCommandQueue: commandQueue])
    renderer.layer = layer
    renderer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
    // the renderer takes the layer tree when the transaction commits
    CATransaction.flush()
    renderer.beginFrame(atTime: time ?? CACurrentMediaTime(), timeStamp: nil)
    renderer.addUpdate(renderer.bounds)
    renderer.render()
    renderer.endFrame()

    // a command buffer committed after the renderer's work on the same queue completes after it
    let fence = commandQueue.makeCommandBuffer()
    fence?.commit()
    fence?.waitUntilCompleted()
    renderer.layer = nil

    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { buffer in
      if let baseAddress = buffer.baseAddress {
        texture.getBytes(baseAddress, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
      }
    }
    return RenderedPixels(width: width, height: height, bytes: bytes)
  }
}

/// The pixels that a window shows for a view, in BGRA, premultiplied, from the bottom row up.
struct RenderedPixels: Equatable {

  let width: Int
  let height: Int
  let bytes: [UInt8]

  /// The number of pixels with any ink.
  var inkedPixelCount: Int {
    stride(from: 3, to: bytes.count, by: 4).filter { bytes[$0] > 0 }.count
  }

  /// Returns the number of pixels that differ from other pixels of the same size, or `Int.max` for another size.
  func differingPixelCount(from other: RenderedPixels) -> Int {
    guard width == other.width, height == other.height else {
      return Int.max
    }
    return stride(from: 0, to: bytes.count, by: 4).filter { index in
      (0 ..< 4).contains { bytes[index + $0] != other.bytes[index + $0] }
    }.count
  }
}

#endif
