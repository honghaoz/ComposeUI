//
//  PinstripesLayer.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/27/26.
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

import QuartzCore

import ComposeUI

/// A layer that fills its bounds with pinstripes, with its background color between them.
final class PinstripesLayer: CALayer {

  /// The direction that stripes run in.
  enum Axis {

    /// Rows of stripes.
    case horizontal

    /// Columns of stripes.
    case vertical
  }

  /// The direction that the stripes run in.
  var axis: Axis = .horizontal {
    didSet {
      if axis != oldValue {
        setNeedsLayout()
      }
    }
  }

  /// The thickness of a stripe, across its direction. Must be greater than 0.
  var stripeThickness: CGFloat = Constants.stripeThickness {
    didSet {
      assert(stripeThickness > 0, "a stripe needs a thickness greater than 0")
      if stripeThickness != oldValue {
        setNeedsLayout()
      }
    }
  }

  /// The space between two stripes. Must not be negative.
  var stripeSpacing: CGFloat = Constants.stripeSpacing {
    didSet {
      assert(stripeSpacing >= 0, "the space between stripes can't be negative")
      if stripeSpacing != oldValue {
        setNeedsLayout()
      }
    }
  }

  /// The distance from the edge of the layer's bounds where its y, or its x for vertical stripes, is the least, to the
  /// start of a stripe, in the layer's coordinates, as its sublayers' frames are.
  var stripeOffset: CGFloat = 0 {
    didSet {
      if stripeOffset != oldValue {
        setNeedsLayout()
      }
    }
  }

  /// The color of the stripes.
  var stripeColor: CGColor? {
    get {
      stripesLayer.fillColor
    }
    set {
      stripesLayer.disableActions(for: "fillColor") {
        stripesLayer.fillColor = newValue
      }
    }
  }

  /// The shape layer that draws the stripes, made lazily, so that a presentation copy doesn't make one.
  private lazy var stripesLayer = CAShapeLayer()

  override init() {
    super.init()

    backgroundColor = Constants.backgroundColor
    stripesLayer.fillColor = Constants.stripeColor
    addSublayer(stripesLayer)
  }

  override init(layer: Any) {
    guard let layer = layer as? PinstripesLayer else {
      fatalError("expect the `layer` to be the same type during an animation.") // swiftlint:disable:this fatal_error
    }

    axis = layer.axis
    stripeThickness = layer.stripeThickness
    stripeSpacing = layer.stripeSpacing
    stripeOffset = layer.stripeOffset
    super.init(layer: layer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override func layoutSublayers() {
    super.layoutSublayers()

    // the stripes are the rects of one shape layer's path, which Core Animation renders for less than a replicator of
    // one stripe or a layer for each stripe: at most a third of their cost over a plain layer in each frame of a resize,
    // and a tenth with 1 pt stripes
    let path = Self.path(axis: axis, size: bounds.size, thickness: stripeThickness, spacing: stripeSpacing, offset: stripeOffset)
    stripesLayer.disableActions(for: "position", "bounds", "path") {
      stripesLayer.frame = bounds
      stripesLayer.path = path
    }
  }

  /// The stripes across a size, cut at its edges, since a shape layer draws its path past its bounds.
  private static func path(axis: Axis, size: CGSize, thickness: CGFloat, spacing: CGFloat, offset: CGFloat) -> CGPath {
    let path = CGMutablePath()
    guard thickness > 0, spacing >= 0 else {
      return path
    }

    let length: CGFloat
    switch axis {
    case .horizontal:
      length = size.height
    case .vertical:
      length = size.width
    }

    let period = thickness + spacing
    // from the last stripe that starts before the edge, which can reach past it, and by index, so that the stripes far
    // from the offset don't gather the rounding of a sum
    var index = (-offset / period).rounded(.down)
    var start = offset + index * period
    while start < length {
      let lower = max(start, 0)
      let upper = min(start + thickness, length)
      if upper > lower {
        switch axis {
        case .horizontal:
          path.addRect(CGRect(x: 0, y: lower, width: size.width, height: upper - lower))
        case .vertical:
          path.addRect(CGRect(x: lower, y: 0, width: upper - lower, height: size.height))
        }
      }
      index += 1
      start = offset + index * period
    }
    return path
  }

  // MARK: - Constants

  private enum Constants {

    /// The thickness of stripes.
    static let stripeThickness: CGFloat = 4

    /// The space between stripes.
    static let stripeSpacing: CGFloat = 4

    /// The color of stripes.
    static let stripeColor = CGColor(srgbRed: 0.9725, green: 0.9725, blue: 0.9725, alpha: 1)

    /// The color between stripes.
    static let backgroundColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)
  }
}
