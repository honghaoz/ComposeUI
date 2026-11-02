//
//  Playground+TrafficLights.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/1/26.
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

  /// A window's traffic light buttons in three sizes, the smallest of which is a window's own on macOS.
  final class TrafficLights: ComposeView {

    /// The height that the view needs for its rows.
    static var preferredHeight: CGFloat {
      let rowsHeight = Constants.scales.reduce(0) { $0 + Constants.windowButtonDiameter * $1 }
      return rowsHeight + Constants.rowSpacing * CGFloat(Constants.scales.count - 1) + Constants.verticalPadding * 2
    }

    /// The index of the row that the pointer is over.
    private var hoveredRow: Int?

    /// Whether the window is key, which shows the buttons' colors.
    private var isKeyWindow: Bool {
      #if canImport(AppKit)
      return window?.isKeyWindow ?? true
      #endif

      #if canImport(UIKit)
      // ComposeView refreshes when the key window changes only on AppKit, so the buttons keep their colors on UIKit
      return true
      #endif
    }

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(spacing: Constants.rowSpacing) {
        for (row, scale) in Constants.scales.enumerated() {
          buttons(row: row, diameter: Constants.windowButtonDiameter * scale)
        }
      }
      .frame(width: .flexible, height: .flexible)
    }

    private func buttons(row: Int, diameter: CGFloat) -> some ComposeNode {
      let isHovered = hoveredRow == row
      let isActive = isKeyWindow || isHovered

      return HStack(spacing: diameter * Constants.windowButtonSpacing / Constants.windowButtonDiameter) {
        for button in TrafficLightButton.allCases {
          trafficLight(button, diameter: diameter, isActive: isActive, showsGlyph: isHovered)
        }
      }
      // the pointer is tracked on AppKit only, since ComposeUI has no hover tracking on UIKit, see `onHover` in the
      // ideas at the end
      #if canImport(AppKit)
      .overlay {
        ViewNode<HoverTrackingView>(update: { [weak self] view, _ in
          view.onHoverChange = { isHovering in
            self?.updateHoveredRow(row, isHovering: isHovering)
          }
        })
      }
      #endif
    }

    private func updateHoveredRow(_ row: Int, isHovering: Bool) {
      if isHovering {
        hoveredRow = row
      } else if hoveredRow == row {
        hoveredRow = nil
      }
      setNeedsRefresh(animated: false)
    }

    private func trafficLight(_ button: TrafficLightButton, diameter: CGFloat, isActive: Bool, showsGlyph: Bool) -> some ComposeNode {
      let color = isActive ? ThemedColor(button.color) : Constants.inactiveColor

      return ButtonNode { state in
        let isPressed = Self.isPressed(state)
        Self.light(button, color: color, diameter: diameter, isPressed: isPressed, showsGlyph: showsGlyph || isPressed)
      } onTap: {
        print("\(button) tapped")
      }
      .willInsert { renderable, _ in
        // a window's buttons change at once
        (renderable.view as? ButtonView)?.animationBehavior = .disabled
      }
      .frame(diameter)
      .dropShadow(
        color: .white,
        opacity: Constants.shadowOpacity,
        radius: Constants.shadowBlurRadius * diameter,
        offset: CGSize(width: 0, height: Constants.shadowVerticalOffset * diameter),
        path: { CGPath(ellipseIn: CGRect(origin: .zero, size: $0), transform: nil) }
      )
    }

    private static func isPressed(_ state: ButtonState) -> Bool {
      switch state {
      case .pressed:
        return true
      case .normal,
           .hovered,
           .selected,
           .disabled:
        return false
      }
    }

    /// The light of a button, which keeps the same nodes in every state, so that the stack keeps their renderables.
    private static func light(_ button: TrafficLightButton, color: ThemedColor, diameter: CGFloat, isPressed: Bool, showsGlyph: Bool) -> some ComposeNode {
      ZStack {
        ColorNode(color)
          .cornerRadius(diameter / 2, cornerCurve: .circular)

        ColorNode(isPressed ? Constants.pressedColor : .clear)
          .cornerRadius(diameter / 2, cornerCurve: .circular)

        // the glow comes before the lower highlight, instead of after it as in the gist, so that it's right over the
        // light's color, which its blended color is for
        highlight(
          color: blended(color, adding: Constants.lowerGlowOpacity),
          opacity: 1,
          blurRadius: Constants.lowerGlowBlurRadius * diameter,
          path: lowerGlowPath(in:)
        )

        highlight(
          color: ThemedColor(.white),
          opacity: Constants.lowerHighlightOpacity,
          blurRadius: Constants.lowerHighlightBlurRadius * diameter,
          path: lowerHighlightPath(in:)
        )

        glyph(button, isVisible: showsGlyph)

        highlight(
          color: ThemedColor(.white),
          opacity: Constants.upperHighlightOpacity,
          blurRadius: Constants.upperHighlightBlurRadius * diameter,
          path: upperHighlightPath(in:)
        )

        InnerShadowNode(
          color: blended(color, adding: -Constants.rimOpacity),
          opacity: Themed<CGFloat>(1),
          radius: Themed<CGFloat>(Constants.rimBlurRadius * diameter),
          offset: Themed<CGSize>(CGSize(width: 0, height: Constants.rimVerticalOffset * diameter)),
          paths: { size in
            let bounds = CGRect(origin: .zero, size: size)
            let inset = Constants.rimWidth / 2 * size.width
            return InnerShadowPaths(
              shadowPath: CGPath(ellipseIn: bounds.insetBy(dx: inset, dy: inset), transform: nil),
              clipPath: CGPath(ellipseIn: bounds, transform: nil)
            )
          }
        )
      }
    }

    /// A shape, blurred by drawing only the shadow that it casts, since ComposeUI has no blur.
    ///
    /// The shadow is cut out of the ring around the light, which keeps the blur inside the light's circle, as the
    /// gist's clip does.
    private static func highlight(color: ThemedColor, opacity: CGFloat, blurRadius: CGFloat, path: @escaping (CGSize) -> CGPath) -> some ComposeNode {
      DropShadowNode(
        color: color,
        opacity: Themed<CGFloat>(opacity),
        radius: Themed<CGFloat>(blurRadius),
        offset: Themed<CGSize>(.zero),
        paths: { size in
          DropShadowPaths(shadowPath: path(size), cutoutPath: ringPath(in: size))
        }
      )
    }

    /// A node that fills the path of a button's glyph, a layer node that stands in for a shape node.
    private static func glyph(_ button: TrafficLightButton, isVisible: Bool) -> some ComposeNode {
      LayerNode<CAShapeLayer>(update: { layer, _ in
        let path = button.glyphPath(in: layer.bounds.size)
        let fillColor = isVisible ? Constants.glyphColor.cgColor : nil
        layer.disableActions(for: "path", "fillColor") {
          layer.path = path
          layer.fillColor = fillColor
        }
      })
    }

    /// The color that the gist's blend of white or black gives over a light's color.
    ///
    /// The gist lightens its lower glow with the plus lighter blend mode, which adds the glow's opacity to each
    /// component of the color below it, and darkens its rim with plus darker, which subtracts the rim's opacity.
    /// ComposeUI has no blend modes, so the glow and the rim are drawn opaque, in the color that the blend gives over
    /// the light's color, which is below most of them. Normal blending of that color then changes each component by as
    /// much as the blend does.
    ///
    /// - Parameters:
    ///   - color: The light's color.
    ///   - amount: The opacity of the blend's white, or minus the opacity of its black.
    /// - Returns: The color that the blend gives.
    private static func blended(_ color: ThemedColor, adding amount: CGFloat) -> ThemedColor {
      func blended(_ color: Color) -> Color {
        #if canImport(AppKit)
        // AppKit gives the components of a color in an RGB color space only, unlike the light's gray in a non-key window
        let color = color.usingColorSpace(.sRGB) ?? color
        #endif

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color(
          red: min(max(red + amount, 0), 1),
          green: min(max(green + amount, 0), 1),
          blue: min(max(blue + amount, 0), 1),
          alpha: 1
        )
      }
      return ThemedColor(light: blended(color.light), dark: blended(color.dark))
    }

    // MARK: - Paths

    // The paths are for the light's size, and follow the gist's shapes, whose sizes are fractions of the diameter.

    /// The lower highlight, the light's circle inset and a smaller circle below its center overlapping.
    private static func lowerHighlightPath(in size: CGSize) -> CGPath {
      let diameter = size.width
      return lensPath(
        centerX: diameter / 2,
        upper: (centerY: diameter / 2, radius: (0.5 - Constants.lowerHighlightInset) * diameter),
        lower: (
          centerY: (0.5 + Constants.lowerHighlightOffset * Constants.lowerHighlightScale) * diameter,
          radius: 0.5 * Constants.lowerHighlightScale * diameter
        )
      )
    }

    /// The lower glow, a small circle at the bottom of the light.
    private static func lowerGlowPath(in size: CGSize) -> CGPath {
      let diameter = size.width
      let radius = 0.5 * Constants.lowerGlowScale * diameter
      let center = CGPoint(x: diameter / 2, y: (0.5 + Constants.lowerGlowOffset * Constants.lowerGlowScale) * diameter)
      return CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
    }

    /// The upper highlight, the top of the light's circle inset, down to where the gist's gradient fades it out.
    private static func upperHighlightPath(in size: CGSize) -> CGPath {
      let diameter = size.width
      let center = CGPoint(x: diameter / 2, y: diameter / 2)
      let radius = (0.5 - Constants.upperHighlightInset) * diameter
      // how far each end of the bottom edge is around the circle from the horizontal through its center
      let angle = asin((center.y - Constants.upperHighlightBottom * diameter) / radius)

      let path = CGMutablePath()
      path.addRelativeArc(center: center, radius: radius, startAngle: .pi + angle, delta: .pi - 2 * angle)
      path.closeSubpath()
      return path
    }

    /// The ring around the light: a rect with the light's circle as a hole, which the even-odd rule of a cutout leaves
    /// uncut. It reaches a diameter past the circle, beyond the blur of each highlight.
    private static func ringPath(in size: CGSize) -> CGPath {
      let bounds = CGRect(origin: .zero, size: size)
      let path = CGMutablePath()
      path.addRect(bounds.insetBy(dx: -size.width, dy: -size.height))
      path.addEllipse(in: bounds)
      return path
    }

    /// The region where two circles on the same vertical line overlap, the upper circle's center above the lower's.
    private static func lensPath(centerX: CGFloat, upper: (centerY: CGFloat, radius: CGFloat), lower: (centerY: CGFloat, radius: CGFloat)) -> CGPath {
      // the circles cross where their equations meet, at the same height on both sides
      let distance = lower.centerY - upper.centerY
      let crossingY = (upper.centerY + lower.centerY) / 2 + (upper.radius * upper.radius - lower.radius * lower.radius) / (2 * distance)
      let halfWidth = sqrt(upper.radius * upper.radius - (crossingY - upper.centerY) * (crossingY - upper.centerY))

      let upperStartAngle = atan2(crossingY - upper.centerY, halfWidth)
      let lowerStartAngle = atan2(crossingY - lower.centerY, -halfWidth)
      let lowerEndAngle = atan2(crossingY - lower.centerY, halfWidth)

      let path = CGMutablePath()
      // the upper circle's bottom arc, from the right crossing to the left one
      path.addRelativeArc(center: CGPoint(x: centerX, y: upper.centerY), radius: upper.radius, startAngle: upperStartAngle, delta: .pi - 2 * upperStartAngle)
      // the lower circle's top arc, back to the right crossing
      path.addRelativeArc(center: CGPoint(x: centerX, y: lower.centerY), radius: lower.radius, startAngle: lowerStartAngle, delta: lowerEndAngle - lowerStartAngle)
      path.closeSubpath()
      return path
    }

    // MARK: - Constants

    private enum Constants {

      /// The diameter of a window's buttons on macOS 26.
      static let windowButtonDiameter: CGFloat = 14

      /// The space between a window's buttons on macOS 26.
      static let windowButtonSpacing: CGFloat = 9

      /// The sizes of the rows, as multiples of a window's buttons.
      static let scales: [CGFloat] = [5, 3, 1]

      static let rowSpacing: CGFloat = 28
      static let verticalPadding: CGFloat = 36

      /// The color of a window's buttons on macOS 26 while the window isn't key.
      static let inactiveColor = ThemedColor(light: Color(white: 0.863, alpha: 1), dark: Color(white: 0.137, alpha: 1))

      /// The color over a pressed button, which darkens it as a window on macOS 26 does.
      static let pressedColor = Color(white: 0, alpha: 0.17)

      /// The color of a window's glyphs on macOS 26.
      static let glyphColor = Color(white: 0, alpha: 0.5)

      // The gloss, in fractions of the diameter, from the gist's values for its 370 pt diameter.

      static let lowerHighlightOffset: CGFloat = 1 / 1.8
      static let lowerHighlightScale: CGFloat = 0.8
      static let lowerHighlightInset: CGFloat = 20 / 370
      static let lowerHighlightBlurRadius: CGFloat = 60 / 370
      static let lowerHighlightOpacity: CGFloat = 0.6

      static let lowerGlowOffset: CGFloat = 1 / 1.1
      static let lowerGlowScale: CGFloat = 0.5
      static let lowerGlowBlurRadius: CGFloat = 40 / 370

      /// The opacity of the gist's glow, which its plus lighter blend adds to the light's color.
      static let lowerGlowOpacity: CGFloat = 0.2

      static let upperHighlightInset: CGFloat = 40 / 370

      /// Where the upper highlight ends, which stands in for the gist's gradient that fades it out from 0.175 to 0.375
      /// of the diameter, since ComposeUI has no gradient node.
      static let upperHighlightBottom: CGFloat = 0.29

      /// The gist's blur of 20 pt widened, so that the highlight fades out over about as far as the gist's gradient.
      static let upperHighlightBlurRadius: CGFloat = 24 / 370

      /// The highlight's opacity, below the gist's full white, which the wider blur would show brighter at the top.
      static let upperHighlightOpacity: CGFloat = 0.85

      static let rimWidth: CGFloat = 44 / 370
      static let rimBlurRadius: CGFloat = 10 / 370

      /// The opacity of the rim, which its plus darker blend subtracts from the light's color, between the gist's 0.5
      /// at the top and 0.3 at the bottom.
      static let rimOpacity: CGFloat = 0.4

      /// How far the rim's shadow moves down, which makes the rim wider at the top and narrower at the bottom, in place
      /// of the gist's gradient from the top to the bottom.
      static let rimVerticalOffset: CGFloat = 5.5 / 370

      static let shadowBlurRadius: CGFloat = 4 / 370
      static let shadowVerticalOffset: CGFloat = 10 / 370
      static let shadowOpacity: CGFloat = 0.4
    }
  }
}

// MARK: - TrafficLightButton

/// The buttons in a window's title bar, in their order.
private enum TrafficLightButton: CaseIterable {

  case close
  case minimize
  case zoom

  /// The color of the button on macOS 26 while its window is key.
  var color: Color {
    switch self {
    case .close:
      return Color(red: 1, green: 0.361, blue: 0.373, alpha: 1)
    case .minimize:
      return Color(red: 0.98, green: 0.784, blue: 0, alpha: 1)
    case .zoom:
      return Color(red: 0.204, green: 0.78, blue: 0.349, alpha: 1)
    }
  }

  /// The path of the button's glyph for a light's size: a cross, a bar, and the two corners of the full screen glyph.
  func glyphPath(in size: CGSize) -> CGPath {
    // the glyphs' coordinates are in the points of a window's 14 pt button, which they're measured in
    let unit = size.width / 14
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: x * unit, y: y * unit)
    }

    let path = CGMutablePath()
    switch self {
    case .close:
      path.move(to: point(4.25, 4.25))
      path.addLine(to: point(9.75, 9.75))
      path.move(to: point(9.75, 4.25))
      path.addLine(to: point(4.25, 9.75))
      return path.copy(strokingWithWidth: 2 * unit, lineCap: .round, lineJoin: .round, miterLimit: 10)
    case .minimize:
      path.move(to: point(4, 7))
      path.addLine(to: point(10, 7))
      return path.copy(strokingWithWidth: 2 * unit, lineCap: .round, lineJoin: .round, miterLimit: 10)
    case .zoom:
      path.move(to: point(9, 4))
      path.addArc(tangent1End: point(4, 4), tangent2End: point(4, 9), radius: unit)
      path.addLine(to: point(4, 9))
      path.closeSubpath()
      path.move(to: point(5, 10))
      path.addArc(tangent1End: point(10, 10), tangent2End: point(10, 5), radius: unit)
      path.addLine(to: point(10, 5))
      path.closeSubpath()
      return path
    }
  }
}

// MARK: - HoverTrackingView

#if canImport(AppKit)

/// A view that tells when the pointer enters or exits it, and lets the views below it take the clicks.
private final class HoverTrackingView: BaseView {

  /// The block to call with whether the pointer is over the view.
  var onHoverChange: ((_ isHovering: Bool) -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)

    // tracks in an inactive window too, where a window's buttons also show their glyphs under the pointer
    addTrackingArea(
      NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
    )
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override func mouseEntered(with event: NSEvent) {
    onHoverChange?(true)
  }

  override func mouseExited(with event: NSEvent) {
    onHoverChange?(false)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

#endif

// MARK: - Ideas

// Components that would replace the stand-ins in this file:
//
// - `ShapeNode`: a node that fills or strokes a path made for its size, with a `CAShapeLayer`. It would draw the
//   glyphs, which a `LayerNode<CAShapeLayer>` draws here, and could animate a path's changes with the additive path
//   animations that the shadow nodes use.
// - `GradientNode`: a node that draws a linear or radial gradient between themed colors, with a `CAGradientLayer`. It
//   would draw the gist's gradients, which a shorter highlight with a wider blur, and a rim that's wider at the top,
//   stand in for here.
// - `onHover(_:)`: a modifier that calls a block when the pointer enters or exits a node's frame, through a tracking
//   area on AppKit and a hover gesture recognizer on UIKit, for a pointer on iPadOS. It would track the pointer over a
//   row of buttons, which a tracking view does here on AppKit only, since `ButtonNode` tracks only its own button, and
//   would show the glyphs on iPadOS too.

// References:
// https://x.com/Barbapapapps/status/2113312625341640839 (https://gist.github.com/juliensagot/cd44554c49a1c77536eda73bbffe2859)
