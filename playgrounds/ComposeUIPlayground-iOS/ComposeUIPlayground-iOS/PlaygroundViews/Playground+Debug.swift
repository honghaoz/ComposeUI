//
//  Playground+Debug.swift
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

import ComposeUI

extension Playground {

  /// Formatting helpers for logging layer and animation state in playground pages.
  enum Debug {

    /// Describes the layer's attached animations, with each animation's endpoints and elapsed time.
    static func describeAnimations(of layer: CALayer) -> String {
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

    /// Describes an animation endpoint value.
    static func describeValue(_ value: Any?) -> String {
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

    static func format(_ value: Double) -> String {
      String(format: "%.3f", value)
    }

    static func format(_ value: Float) -> String {
      String(format: "%.3f", value)
    }

    static func format(_ value: CGFloat) -> String {
      String(format: "%.3f", value)
    }

    static func format(_ point: CGPoint) -> String {
      String(format: "(%.1f, %.1f)", point.x, point.y)
    }
  }

  /// Makes a standard playground action button.
  ///
  /// - Parameters:
  ///   - title: The button title.
  ///   - fontSize: The title's font size. `nil` uses the label's default font.
  ///   - onTap: The tap handler.
  static func button(title: String, fontSize: CGFloat? = nil, onTap: @escaping () -> Void) -> ComposeNode {
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
        var label = Label(title)
          .textColor(.white)
          .selectable(false)
        if let fontSize {
          label = label.font(.systemFont(ofSize: fontSize))
        }
        ColorNode(backgroundColor)
          .cornerRadius(6)
          .overlay {
            label
          }
      },
      onTap: onTap
    )
  }
}
