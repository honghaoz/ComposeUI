//
//  DropShadowLayer.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/1/25.
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

import QuartzCore

/// A layer that renders a drop shadow.
open class DropShadowLayer: CALayer {

  /// The drop shadow layer never clips the content.
  override public final var masksToBounds: Bool {
    get { super.masksToBounds }
    set {} // do nothing
  }

  override init() {
    super.init()

    #if canImport(AppKit)
    contentsScale = NSScreen.main?.backingScaleFactor ?? Constants.defaultScaleFactor
    #endif

    #if canImport(UIKit)
    #if os(visionOS)
    contentsScale = Constants.defaultScaleFactor
    wantsDynamicContentScaling = true
    #else
    contentsScale = UIScreen.main.scale
    #endif
    #endif

    super.masksToBounds = false
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override init(layer: Any) {
    guard let layer = layer as? DropShadowLayer else {
      // swiftlint:disable:next fatal_error
      fatalError("expect the `layer` to be the same type during an animation.")
    }

    super.init(layer: layer)

    // needs to copy all properties
    contentsScale = layer.contentsScale

    shadowColor = layer.shadowColor
    shadowOpacity = layer.shadowOpacity
    shadowRadius = layer.shadowRadius
    shadowOffset = layer.shadowOffset
    shadowPath = layer.shadowPath
  }

  /// Update the drop shadow layer with a new shadow.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - opacity: The opacity of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - path: The path of the shadow.
  ///   - animationTiming: The animation timing applied to the shadow change. Default to `nil`.
  public func update(color: Color,
                     opacity: CGFloat,
                     radius: CGFloat,
                     offset: CGSize,
                     path: @escaping (DropShadowLayer) -> CGPath,
                     animationTiming: AnimationTiming? = nil)
  {
    let color = color.cgColor
    let opacity = Float(opacity)

    if let animationTiming {
      animate(
        keyPath: "shadowColor",
        timing: animationTiming,
        from: { $0.presentation()?.shadowColor },
        to: { _ in color }
      )
      animate(keyPath: "shadowOpacity", to: opacity, timing: animationTiming)
      animate(keyPath: "shadowRadius", to: radius, timing: animationTiming)
      animate(keyPath: "shadowOffset", to: offset, timing: animationTiming)
      animate(
        keyPath: "shadowPath",
        timing: animationTiming,
        from: { $0.presentation()?.shadowPath },
        to: { path($0 as! DropShadowLayer) } // swiftlint:disable:this force_cast
      )
    } else {
      disableActions(for: "shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath") {
        shadowColor = color
        shadowOpacity = opacity
        shadowRadius = radius
        shadowOffset = offset
        shadowPath = path(self)
      }
    }
  }
}
