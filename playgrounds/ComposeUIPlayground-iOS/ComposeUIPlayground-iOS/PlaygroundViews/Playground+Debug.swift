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

    static func format(_ rect: CGRect) -> String {
      String(format: "(%.1f, %.1f, %.1f, %.1f)", rect.origin.x, rect.origin.y, rect.width, rect.height)
    }
  }

  /// Adds a small centered name label to a box layer, so the box's renderable kind is identifiable on screen.
  ///
  /// The label is a sublayer of the box's layer (instead of a separate node), so it rides along with the box during
  /// animations and transitions, and the box stays a single renderable for lifecycle logging. Safe to call from a
  /// render pass update: the label is created once and its frame is only written when the box's bounds changed.
  ///
  /// - Parameters:
  ///   - name: The name to show on the box.
  ///   - layer: The box's layer.
  ///   - scale: The label's contents scale, see `displayScale(of:)`.
  static func addBoxNameLabel(_ name: String, to layer: CALayer, scale: CGFloat) {
    let labelLayerName = "box-name-label"

    let textLayer: CATextLayer
    if let existing = layer.sublayers?.first(where: { $0.name == labelLayerName }) as? CATextLayer {
      textLayer = existing
    } else {
      textLayer = CATextLayer()
      textLayer.name = labelLayerName
      textLayer.string = name
      // UIFont/NSFont is toll-free bridged to the CTFont that CATextLayer expects
      textLayer.font = Font.systemFont(ofSize: BoxNameStyle.fontSize, weight: .medium)
      textLayer.fontSize = BoxNameStyle.fontSize
      textLayer.foregroundColor = Color.white.cgColor
      textLayer.alignmentMode = .center
      textLayer.contentsScale = scale
      layer.addSublayer(textLayer)
    }

    let frame = CGRect(
      x: 0,
      y: (layer.bounds.height - BoxNameStyle.height) / 2,
      width: layer.bounds.width,
      height: BoxNameStyle.height
    )
    if textLayer.frame != frame {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      textLayer.frame = frame
      CATransaction.commit()
    }
  }

  /// The display scale of the view's environment, for crisp layer text.
  ///
  /// - Parameter view: The view whose window or screen provides the scale.
  /// - Returns: The display scale.
  static func displayScale(of view: View) -> CGFloat {
    #if canImport(AppKit)
    return view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? BoxNameStyle.fallbackDisplayScale
    #else
    let scale = view.traitCollection.displayScale
    // an unattached view can report an unspecified (0) display scale, fall back to a retina scale
    return scale > 0 ? scale : BoxNameStyle.fallbackDisplayScale
    #endif
  }

  /// Makes a standard playground action button.
  ///
  /// The button renders as a raised, bordered rounded rect that flattens while pressed, so it reads as a control next
  /// to the pages' plain color boxes. The title is bounded by the button's width and truncates instead of overflowing
  /// into neighboring buttons.
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

        // a pressed button sits flat: the lift shadow and the bevel highlight are hidden (via opacity, so the node
        // structure is stable across state changes), leaving the darker background as the pressed look
        let isPressed = state == .pressed || state == .selected

        var label = Label(title)
          .textColor(.white)
          .selectable(false)
          // bound the title to the button's width, so a long title truncates instead of painting over neighbors
          .fixedSize(width: false, height: true)
        if let fontSize {
          label = label.font(.systemFont(ofSize: fontSize))
        }

        ColorNode(backgroundColor)
          .cornerRadius(ButtonStyle.cornerRadius)
          .border(color: ButtonStyle.borderColor, width: 1)
          .overlay {
            // a top inner highlight, inset to sit within the border, gives the button a raised, bevelled face
            InnerShadowNode(
              color: .white,
              opacity: isPressed ? 0 : ButtonStyle.bevelOpacity,
              radius: 0,
              offset: CGSize(width: 0, height: 1),
              path: { renderable in
                let size = renderable.frame.size
                let cornerRadius = ButtonStyle.cornerRadius - 1
                return CGPath(
                  roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                  cornerWidth: cornerRadius,
                  cornerHeight: cornerRadius,
                  transform: nil
                )
              }
            )
            .padding(1)
          }
          .dropShadow(
            color: .black,
            opacity: isPressed ? 0 : ButtonStyle.shadowOpacity,
            radius: ButtonStyle.shadowRadius,
            offset: ButtonStyle.shadowOffset,
            path: { renderable in
              let size = renderable.frame.size
              return CGPath(
                roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                cornerWidth: ButtonStyle.cornerRadius,
                cornerHeight: ButtonStyle.cornerRadius,
                transform: nil
              )
            }
          )
          .overlay {
            label.padding(horizontal: ButtonStyle.titlePadding)
          }
      },
      onTap: onTap
    )
  }
}

// MARK: - Constants

/// The shared style values for the box name labels.
private enum BoxNameStyle {

  /// The font size of the name label.
  static let fontSize: CGFloat = 11

  /// The height of the name label.
  static let height: CGFloat = 14

  /// The display scale to use when the view's environment doesn't provide one.
  static let fallbackDisplayScale: CGFloat = 2
}

/// The shared style values for `Playground.button`.
private enum ButtonStyle {

  /// The button's corner radius.
  static let cornerRadius: CGFloat = 6

  /// The border color, translucent black so it works with all state background colors.
  static let borderColor = Color(white: 0, alpha: 0.2)

  /// The opacity of the top bevel highlight.
  static let bevelOpacity: CGFloat = 0.3

  /// The opacity of the lift shadow under the button.
  static let shadowOpacity: CGFloat = 0.25

  /// The blur radius of the lift shadow.
  static let shadowRadius: CGFloat = 1.5

  /// The offset of the lift shadow.
  static let shadowOffset = CGSize(width: 0, height: 1)

  /// The horizontal padding between the title and the button's edges.
  static let titlePadding: CGFloat = 6
}
