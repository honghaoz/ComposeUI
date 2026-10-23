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
///
/// A render draws again only the layers that the changes since the last render marked for display, as a window's commit
/// does, so a test can tell a change that doesn't draw again from one that does.
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

  /// The renderer that shows the view's layer, `nil` before the first render.
  ///
  /// The view's layer stays in the renderer from one render to the next, instead of moving into a new renderer for each
  /// render, since moving a layer into a renderer or out of one marks the layers that draw for display, which would draw
  /// each of them again on each render, whatever a change marked.
  private var layerRenderer: LayerRenderer?

  /// The color space that the window shows its pixels in, which Core Animation draws the layers' backing stores in.
  ///
  /// Setting it sets the window's color space, as an app does.
  var colorSpace: NSColorSpace {
    didSet {
      window.colorSpace = colorSpace
    }
  }

  /// Creates a window with a view of a size to render. Throws `XCTSkip` without a Metal device.
  ///
  /// - Parameters:
  ///   - size: The size of the view to render.
  ///   - scale: The scale of the window's backing store. The default is 2, the scale of a Retina screen.
  ///   - colorSpace: The window's color space, which the pixels are rendered in. The default is sRGB, instead of the
  ///     screen's, so the pixels are the same on each machine.
  init(size: CGSize, scale: CGFloat = 2, colorSpace: NSColorSpace = .sRGB) throws {
    guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
      throw XCTSkip("rendering through CARenderer requires a Metal device")
    }
    self.commandQueue = commandQueue
    self.colorSpace = colorSpace

    window = Window(scale: scale)
    window.colorSpace = colorSpace
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
    let layerRenderer = try layerRenderer(width: width, height: height, scale: scale)
    let texture = layerRenderer.texture
    let renderer = layerRenderer.renderer

    // the renderer draws into the same texture on each render, which starts each render transparent, as a new texture
    let bytesPerRow = width * 4
    let transparent = [UInt8](repeating: 0, count: bytesPerRow * height)
    transparent.withUnsafeBytes { buffer in
      if let baseAddress = buffer.baseAddress {
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: baseAddress, bytesPerRow: bytesPerRow)
      }
    }

    // the renderer takes the changes to the layer tree when the transaction commits
    CATransaction.flush()
    renderer.beginFrame(atTime: time ?? CACurrentMediaTime(), timeStamp: nil)
    renderer.addUpdate(renderer.bounds)
    renderer.render()
    renderer.endFrame()

    // a command buffer committed after the renderer's work on the same queue completes after it
    let fence = commandQueue.makeCommandBuffer()
    fence?.commit()
    fence?.waitUntilCompleted()

    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
    bytes.withUnsafeMutableBytes { buffer in
      if let baseAddress = buffer.baseAddress {
        texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
      }
    }
    return RenderedPixels(width: width, height: height, bytes: bytes)
  }

  /// Returns the renderer that shows the view's layer: the last render's renderer, while the layer is still its root, at
  /// the same size, scale and color space, or else a new renderer, which takes the layer.
  ///
  /// - Parameters:
  ///   - width: The width of the view in the window's pixels.
  ///   - height: The height of the view in the window's pixels.
  ///   - scale: The scale of the window's backing store.
  /// - Returns: The renderer, with the texture that it draws into.
  private func layerRenderer(width: Int, height: Int, scale: CGFloat) throws -> LayerRenderer {
    let layer = try XCTUnwrap(view.layer)
    if let layerRenderer, layerRenderer.renderer.layer === layer, layer.superlayer == nil,
       layerRenderer.texture.width == width, layerRenderer.texture.height == height, layerRenderer.scale == scale, layerRenderer.colorSpace == colorSpace
    {
      return layerRenderer
    }

    // a layer is in one renderer at a time, so it leaves the last renderer before a new renderer takes it
    layerRenderer?.renderer.layer = nil

    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try XCTUnwrap(commandQueue.device.makeTexture(descriptor: descriptor))

    // the renderer maps the layer's points to the texture's pixels one to one, so the view's layer scales its sublayers
    // to show their contents one pixel to one pixel
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1)
    CATransaction.commit()

    // the renderer draws the backing stores in its color space, as a window draws them in its own
    var options: [AnyHashable: Any] = [kCARendererMetalCommandQueue: commandQueue]
    if let cgColorSpace = colorSpace.cgColorSpace {
      options[kCARendererColorSpace] = cgColorSpace
    }
    let renderer = CARenderer(mtlTexture: texture, options: options)
    renderer.layer = layer
    renderer.bounds = CGRect(x: 0, y: 0, width: width, height: height)

    let layerRenderer = LayerRenderer(renderer: renderer, texture: texture, scale: scale, colorSpace: colorSpace)
    self.layerRenderer = layerRenderer
    return layerRenderer
  }

  /// A renderer that shows the view's layer, with the texture that it draws into, and the scale and the color space that
  /// it draws at.
  private struct LayerRenderer {

    let renderer: CARenderer
    let texture: MTLTexture
    let scale: CGFloat
    let colorSpace: NSColorSpace
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
