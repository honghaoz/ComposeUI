//
//  RenderableTransition+Scale.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/1/26.
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

public extension RenderableTransition {

  /// Creates a scale transition.
  ///
  /// For insertion, the renderable starts at `from` scale and scales to its natural size at `targetFrame`.
  /// For removal, the renderable scales from its current scale down to `from`.
  ///
  /// The scaling pivots about `anchor`, the point of the renderable that stays fixed while it scales: each
  /// "transform.scale" animation is paired with a same-timing "transform.translation" compensation that keeps the
  /// anchor fixed for any layer anchor point (AppKit anchors view-backing layers at a corner, unlike the center anchor
  /// elsewhere). The compensation is skipped when it is zero, for a center anchor on a center-anchored layer.
  ///
  /// The scale is rendered by additive animations while the model transform rests at identity. The transition owns the
  /// layer's transform and assumes no other writer touches it.
  ///
  /// Reviving a renderable while its scale-out is in flight continues the motion: the insertion's offset from the
  /// removal's model scale cancels the model change, so the rendered scale doesn't jump, and the leftover exit offset
  /// keeps decaying on top while both animations settle into the resting scale. An underdamped timing can overshoot,
  /// which renders a momentarily mirrored scale when the composed scale crosses below zero.
  ///
  /// A zero-duration timing applies the end state and completes immediately when there is no delay, and a zero-duration
  /// revival also clears the leftover exit animations so the snap lands at rest. With a delay, the end state is
  /// scheduled as a snap that applies right after the delay window.
  ///
  /// - Parameters:
  ///   - from: The scale to insert from and remove to. Values above 1 zoom down into place. Defaults to 0.
  ///   - anchor: The point of the renderable that stays fixed while it scales. Defaults to `.center`.
  ///   - timing: The timing of the scale transition.
  ///   - options: The options for the scale transition.
  static func scale(from: CGFloat = 0,
                    anchor: Layout.Alignment = .center, // TODO: replace with https://github.com/honghaoz/ChouTiUI/blob/master/ChouTiUI/Sources/ChouTiUI/Universal/Layout/UnitPoint.swift
                    timing: AnimationTiming = .spring(),
                    options: RenderableTransition.Options = .both) -> Self
  {
    RenderableTransition(
      insert: options.contains(.insert) ? InsertTransition(
        takesOverKeyPaths: Constants.animatedKeyPaths,
        animate: { renderable, context, completion in
          let layer = renderable.layer
          ComposeUI.assert(CATransform3DIsIdentity(layer.transform), "scale insert transition requires an identity model transform")

          guard timing.timing.duration > 0 || timing.delay > 0 else {
            if context.revivalTransform != nil {
              // the taken-over leftover exit animations would render the snapped model off the resting scale until they
              // decay, so a snap clears them
              for keyPath in Constants.animatedKeyPaths {
                layer.removeAnimations(forKeyPath: keyPath)
              }
            }
            renderable.setFrame(context.targetFrame)
            completion()
            return
          }

          let startScale: CGFloat
          let startTranslation: CGSize
          if let revivalTransform = context.revivalTransform {
            // a revival continues from the removal's model transform: the offsets from its scale and translation
            // components cancel the model change exactly, so the rendered transform doesn't move at the revival instant,
            // and the removal's leftover offsets keep decaying on top.
            // the transition owns the transform and writes it through the "transform.scale" and "transform.translation"
            // key paths, so the captured transform's x scale and translation components are those written values.
            startScale = revivalTransform.m11
            startTranslation = CGSize(width: revivalTransform.m41, height: revivalTransform.m42)
          } else {
            startScale = from
            startTranslation = layer.pivotTranslation(towards: anchor.unitPoint, for: from, size: context.targetFrame.size)
          }

          renderable.setFrame(context.targetFrame)

          layer.animate(
            keyPath: "transform.scale",
            timing: timing,
            from: { _ in startScale - 1 },
            to: { _ in CGFloat(0) },
            model: { _ in CGFloat(1) },
            updateAnimation: {
              $0.isAdditive = true
              $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
                completion()
              })
            }
          )

          // the pair shares the scale animation's timing, so the compensation tracks the rendered scale exactly and the
          // completion can ride on the scale animation alone
          if startTranslation != .zero {
            layer.animate(
              keyPath: "transform.translation",
              timing: timing,
              from: { _ in startTranslation },
              to: { _ in CGSize.zero },
              model: { _ in CGSize.zero },
              updateAnimation: {
                $0.isAdditive = true
              }
            )
          }
        }
      ) : nil,
      remove: options.contains(.remove) ? RemoveTransition(
        animatedKeyPaths: Constants.animatedKeyPaths,
        animate: { renderable, _, completion in
          let layer = renderable.layer
          let endTranslation = layer.pivotTranslation(towards: anchor.unitPoint, for: from, size: layer.bounds.size)

          guard timing.timing.duration > 0 || timing.delay > 0 else {
            layer.setKeyPathValue("transform.scale", from)
            if endTranslation != .zero {
              layer.setKeyPathValue("transform.translation", endTranslation)
            }
            completion()
            return
          }

          layer.animate(
            keyPath: "transform.scale",
            to: from,
            timing: timing,
            updateAnimation: {
              $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
                completion()
              })
            }
          )

          if endTranslation != .zero {
            layer.animate(keyPath: "transform.translation", to: endTranslation, timing: timing)
          }
        },
        resetForReuse: { renderable in
          renderable.layer.restoreIdentityTransformIfNeeded()
        }
      ) : nil
    )
  }

  // MARK: - Constants

  /// The enum is nested so it doesn't collide with the module's public `Constants` type.
  private enum Constants {

    /// The root-layer key paths the scale transition animates.
    static let animatedKeyPaths: Set<String> = ["transform.scale", "transform.translation"]
  }
}

private extension Layout.Alignment {

  /// The alignment as a point in the unit coordinate space, with the origin at the top left.
  var unitPoint: CGPoint {
    switch self {
    case .center:
      return CGPoint(x: 0.5, y: 0.5)
    case .left:
      return CGPoint(x: 0, y: 0.5)
    case .right:
      return CGPoint(x: 1, y: 0.5)
    case .top:
      return CGPoint(x: 0.5, y: 0)
    case .bottom:
      return CGPoint(x: 0.5, y: 1)
    case .topLeft:
      return CGPoint(x: 0, y: 0)
    case .topRight:
      return CGPoint(x: 1, y: 0)
    case .bottomLeft:
      return CGPoint(x: 0, y: 1)
    case .bottomRight:
      return CGPoint(x: 1, y: 1)
    }
  }
}

private extension CALayer {

  /// The translation that keeps the layer's `pivot` unit point fixed when it renders at `scale`.
  ///
  /// The transform applies about the layer's `anchorPoint`, so scaling shifts every point except the anchor. The
  /// compensation is the pivot's offset from the anchor, `(pivot - anchorPoint) * size`, scaled by how far the scale
  /// is from resting.
  ///
  /// - Parameters:
  ///   - pivot: The unit point to keep fixed.
  ///   - scale: The rendered scale.
  ///   - size: The layer's rendered size.
  /// - Returns: The compensating translation. Zero when the pivot coincides with the layer's anchor point.
  func pivotTranslation(towards pivot: CGPoint, for scale: CGFloat, size: CGSize) -> CGSize {
    CGSize(
      width: (pivot.x - anchorPoint.x) * size.width * (1 - scale),
      height: (pivot.y - anchorPoint.y) * size.height * (1 - scale)
    )
  }
}
