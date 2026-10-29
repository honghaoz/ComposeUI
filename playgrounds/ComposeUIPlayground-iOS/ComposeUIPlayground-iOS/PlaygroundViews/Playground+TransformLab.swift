//
//  Playground+TransformLab.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/28/26.
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

  /// A lab for the `transform(_:anchor:)` modifier.
  ///
  /// Each section transforms renderables in one case. A tile outlines the frame that the layout gives its renderable,
  /// which the transform doesn't change. The controls change the transforms, insert and remove renderables and resize
  /// them, animated or not, and rebuild a compose view that renders before it joins the window.
  final class TransformLab: ComposeView {

    /// The rotation about the z axis, in degrees.
    private var angle: CGFloat = Constants.angleStep

    /// The index of the scale in `Constants.scales`.
    private var scaleIndex = 0

    /// The rotation of the 3D tile about the y axis, in degrees.
    private var tilt: CGFloat = Constants.angleStep

    /// Whether the controls animate their changes.
    private var isAnimated = true

    /// Whether the insertion section shows its renderables.
    private var showsInsertedItems = true

    /// Whether the resize section's tiles are wide.
    private var isWide = false

    /// The view that holds the prerendered section's compose view.
    private let prerenderedContainer = BaseView()

    /// The prerendered section's compose view, which renders before it joins the window.
    private var prerenderedView: ComposeView?

    override init(frame: CGRect) {
      super.init(frame: frame)

      rebuildPrerenderedView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
    }

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(alignment: .left, spacing: Constants.sectionSpacing) {
        controls
        anchorSection
        renderableSection
        transformSection
        stackSection
        modifierSection
        insertionSection
        scrollingSection
        prerenderedSection
        resizeSection
      }
      .padding(Constants.padding)
      .animation(Constants.timing)
    }

    // MARK: - Controls

    private var controls: ComposeNode {
      VStack(alignment: .left, spacing: Constants.controlSpacing) {
        HStack(spacing: Constants.controlSpacing) {
          button("Rotate") { $0.angle += Constants.angleStep }
          button("Scale") { $0.scaleIndex = ($0.scaleIndex + 1) % Constants.scales.count }
          button("Tilt") { $0.tilt += Constants.angleStep }
          button("Reset") {
            $0.angle = 0
            $0.scaleIndex = 0
            $0.tilt = 0
          }
        }
        HStack(spacing: Constants.controlSpacing) {
          button(showsInsertedItems ? "Remove" : "Insert") { $0.showsInsertedItems.toggle() }
          button(isWide ? "Narrow" : "Widen") { $0.isWide.toggle() }
          button("Rebuild") { $0.rebuildPrerenderedView() }
          button(isAnimated ? "Animation on" : "Animation off", width: Constants.wideButtonWidth) {
            $0.isAnimated.toggle()
          }
        }
      }
    }

    /// A control that changes the lab's state, then refreshes the lab and the prerendered compose view, which shows the
    /// same state.
    private func button(_ title: String,
                        width: CGFloat = Constants.buttonWidth,
                        change: @escaping (TransformLab) -> Void) -> ComposeNode
    {
      Playground.button(title: title, fontSize: Constants.buttonFontSize) { [weak self] in
        guard let self else {
          return
        }
        change(self)
        refresh(animated: isAnimated)
        prerenderedView?.refresh(animated: isAnimated)
      }
      .frame(width: width, height: Constants.buttonHeight)
    }

    // MARK: - Sections

    /// The same rotation about three anchors, each marked with a dot, which the rotation keeps in place.
    private var anchorSection: ComposeNode {
      section("Rotation about an anchor") {
        HStack(alignment: .top, spacing: Constants.tileSpacing) {
          anchorTile("Top left", anchor: .topLeft, alignment: .topLeft, color: Colors.RetroApple.green)
          anchorTile("Center", anchor: .center, alignment: .center, color: Colors.RetroApple.yellow)
          anchorTile("Bottom right", anchor: .bottomRight, alignment: .bottomRight, color: Colors.RetroApple.orange)
        }
      }
    }

    private func anchorTile(_ caption: String,
                            anchor: UnitPoint,
                            alignment: Layout.Alignment,
                            color: Color) -> ComposeNode
    {
      tile(caption) {
        ZStack(alignment: alignment) {
          ColorNode(color)
            .transform(rotation, anchor: anchor)
          ColorNode(Colors.darkBlueGray)
            .cornerRadius(Constants.anchorDotSize / 2)
            .frame(width: Constants.anchorDotSize, height: Constants.anchorDotSize)
        }
      }
    }

    /// The same transform on a layer, a view and a label, which renders a view. AppKit resets a view's layer transform
    /// when it moves, resizes or joins a window, so the views check that the transform survives that on macOS.
    private var renderableSection: ComposeNode {
      section("Layers and views") {
        HStack(alignment: .top, spacing: Constants.tileSpacing) {
          tile("Layer") {
            ColorNode(Colors.RetroApple.red)
              .transform(rotationAndScale)
          }
          tile("View") {
            ViewNode<BaseView>()
              .flexibleSize()
              .backgroundColor(Colors.RetroApple.purple)
              .transform(rotationAndScale)
          }
          tile("Label") {
            label("Label", color: Colors.blueGray)
              .transform(rotationAndScale)
          }
        }
      }
    }

    private var transformSection: ComposeNode {
      section("Scale, skew and 3D") {
        HStack(alignment: .top, spacing: Constants.tileSpacing) {
          tile("Scale") {
            ColorNode(Colors.RetroApple.green)
              .transform(scaleTransform)
          }
          tile("Skew") {
            ColorNode(Colors.RetroApple.yellow)
              .transform(skewTransform)
          }
          tile("3D") {
            ColorNode(Colors.RetroApple.orange)
              .transform(tiltTransform)
          }
        }
      }
    }

    /// A transform on a stack applies to each of the stack's renderables about its own center, not the stack's.
    private var stackSection: ComposeNode {
      section("On a stack, each renderable turns about its own center") {
        HStack(spacing: Constants.stackSpacing) {
          for color in Colors.RetroApple.all {
            ColorNode(color)
              .frame(width: Constants.stackItemSize, height: Constants.stackItemSize)
          }
        }
        .transform(rotation)
      }
    }

    /// A transform with the modifiers that style a layer, and on a label over a background, two renderables that turn
    /// together, since they share a center.
    private var modifierSection: ComposeNode {
      section("With other modifiers") {
        HStack(alignment: .top, spacing: Constants.tileSpacing) {
          tile("Shadow") {
            ColorNode(Colors.RetroApple.yellow)
              .cornerRadius(Constants.cornerRadius)
              .border(color: Colors.darkBlueGray, width: Constants.borderWidth)
              .shadow(
                color: .black,
                opacity: Constants.shadowOpacity,
                radius: Constants.shadowRadius,
                offset: Constants.shadowOffset,
                path: nil
              )
              .transform(rotationAndScale)
          }
          tile("Opacity") {
            ColorNode(Colors.RetroApple.red)
              .opacity(Constants.opacity)
              .transform(rotationAndScale)
          }
          tile("Badge") {
            Label("Badge")
              .font(.systemFont(ofSize: Constants.labelFontSize, weight: .semibold))
              .textColor(.white)
              .selectable(false)
              .padding(horizontal: Constants.badgeHorizontalPadding, vertical: Constants.badgeVerticalPadding)
              .underlay {
                ColorNode(Colors.RetroApple.purple)
                  .cornerRadius(Constants.cornerRadius)
              }
              .transform(rotationAndScale)
          }
        }
      }
    }

    /// Renderables that the "Remove" control removes with their transitions, and that the "Insert" control inserts
    /// already transformed. Removing them moves the sections below, whose views keep their transforms.
    private var insertionSection: ComposeNode {
      section("Insertion and removal") {
        if showsInsertedItems {
          HStack(alignment: .top, spacing: Constants.tileSpacing) {
            tile("Layer, fades") {
              ColorNode(Colors.RetroApple.green)
                .transform(rotationAndScale)
                .transition(.opacity(timing: Constants.timing))
            }
            tile("View, fades") {
              ViewNode<BaseView>()
                .flexibleSize()
                .backgroundColor(Colors.RetroApple.yellow)
                .transform(rotationAndScale)
                .transition(.opacity(timing: Constants.timing))
            }
            tile("Label, slides") {
              label("Label", color: Colors.RetroApple.orange)
                .transform(rotationAndScale)
                .transition(.slide(from: .left, timing: Constants.timing))
            }
          }
        }
      }
    }

    /// Rows that turn one way, the other way or not at all, so that a renderable that scrolling reuses for another row
    /// shows that row's transform, and no transform in a row that has none.
    private var scrollingSection: ComposeNode {
      section("Rows that scroll") {
        ComposeViewNode {
          VStack(spacing: Constants.rowSpacing) {
            for index in 0 ..< Constants.rowCount {
              row(index)
            }
          }
          .padding(vertical: Constants.rowSpacing)
          .animation(Constants.timing)
        }
        .fixedSize(width: false, height: false)
        .frame(width: .flexible, height: Constants.listHeight)
        .underlay {
          LayerNode()
            .border(color: Colors.lightBlueGray, width: 1)
        }
      }
    }

    private func row(_ index: Int) -> ComposeNode {
      let row = ZStack {
        ColorNode(Colors.RetroApple.all[index % Colors.RetroApple.all.count])
          .cornerRadius(Constants.rowCornerRadius)
        Label("Row \(index + 1)")
          .textColor(.white)
          .selectable(false)
      }
      .frame(width: Constants.rowSize.width, height: Constants.rowSize.height)

      switch index % 3 {
      case 0:
        return row.transform(rowRotation)
      case 1:
        return row.transform(CATransform3DInvert(rowRotation))
      default:
        return row
      }
    }

    /// A compose view that renders its views before it joins the window, which the "Rebuild" control replaces. AppKit
    /// resets the transform of a view that joins a window, so this checks that the transform survives that on macOS.
    private var prerenderedSection: ComposeNode {
      section("Rendered before it joins the window") {
        ViewNode(prerenderedContainer)
          .flexibleSize()
          .frame(width: Constants.prerenderedSize.width, height: Constants.prerenderedSize.height)
      }
    }

    @ComposeContentBuilder
    private var prerenderedContent: ComposeContent {
      HStack(spacing: Constants.tileSpacing) {
        ColorNode(Colors.RetroApple.red)
          .transform(rotationAndScale)
          .frame(width: Constants.tileSize.width, height: Constants.tileSize.height)
        ViewNode<BaseView>()
          .flexibleSize()
          .backgroundColor(Colors.RetroApple.purple)
          .transform(rotationAndScale)
          .frame(width: Constants.tileSize.width, height: Constants.tileSize.height)
        label("Label", color: Colors.blueGray)
          .transform(rotationAndScale)
          .frame(width: Constants.tileSize.width, height: Constants.tileSize.height)
      }
      .frame(width: .flexible, height: .flexible)
      .animation(Constants.timing)
    }

    /// Replaces the prerendered section's compose view with a new one, which renders, then joins the window on the next
    /// run loop turn.
    private func rebuildPrerenderedView() {
      prerenderedView?.removeFromSuperview()

      let view = ComposeView { [weak self] in
        self?.prerenderedContent ?? Empty()
      }
      view.frame = CGRect(origin: .zero, size: Constants.prerenderedSize)
      view.refresh(animated: false)
      prerenderedView = view

      DispatchQueue.main.async { [weak self] in
        guard let self, prerenderedView === view else {
          return
        }
        prerenderedContainer.addSubview(view)
      }
    }

    /// Turns about the top left corner of tiles whose width changes. A layer turns about its center, so the transform
    /// moves its anchor to the corner, which stays in place while the frame animates.
    private var resizeSection: ComposeNode {
      section("Resize, turned about the top left") {
        HStack(alignment: .top, spacing: Constants.tileSpacing) {
          tile("Layer", size: resizeTileSize) {
            ColorNode(Colors.RetroApple.green)
              .transform(rotation, anchor: .topLeft)
          }
          tile("View", size: resizeTileSize) {
            ViewNode<BaseView>()
              .flexibleSize()
              .backgroundColor(Colors.RetroApple.orange)
              .transform(rotation, anchor: .topLeft)
          }
        }
      }
    }

    // MARK: - Building Blocks

    private func section(_ title: String, @ComposeContentBuilder content: () -> ComposeContent) -> ComposeNode {
      VStack(alignment: .left, spacing: Constants.titleSpacing) {
        Label(title)
          .font(.systemFont(ofSize: Constants.titleFontSize, weight: .semibold))
          .textColor(Colors.darkBlueGray)
        content()
      }
    }

    /// A tile with a caption above an outline of the frame that the layout gives the content. The outline draws above
    /// the content, so that the content doesn't hide it.
    private func tile(_ caption: String,
                      size: CGSize = Constants.tileSize,
                      @ComposeContentBuilder content: () -> ComposeContent) -> ComposeNode
    {
      VStack(spacing: Constants.captionSpacing) {
        Label(caption)
          .font(.systemFont(ofSize: Constants.captionFontSize))
          .textColor(Colors.darkBlueGray)
        ZStack {
          content()
          LayerNode()
            .border(color: Colors.darkBlueGray, width: 1)
        }
        .frame(width: size.width, height: size.height)
      }
    }

    /// A label, which renders a view, with a background that shows the view's frame.
    private func label(_ text: String, color: Color) -> some ComposeNode {
      Label(text)
        .font(.systemFont(ofSize: Constants.labelFontSize, weight: .semibold))
        .textColor(.white)
        .selectable(false)
        .backgroundColor(color)
    }

    // MARK: - Transforms

    private var rotation: CATransform3D {
      CATransform3DMakeRotation(angle * .pi / 180, 0, 0, 1)
    }

    private var scaleTransform: CATransform3D {
      let scale = Constants.scales[scaleIndex]
      return CATransform3DMakeScale(scale, scale, 1)
    }

    /// The scale, then the rotation.
    private var rotationAndScale: CATransform3D {
      CATransform3DConcat(scaleTransform, rotation)
    }

    /// A skew along the x axis, which follows the rotation, so that the "Rotate" control changes it.
    private var skewTransform: CATransform3D {
      var transform = CATransform3DIdentity
      transform.m21 = Constants.maxSkew * sin(angle * .pi / 180)
      return transform
    }

    /// The rotation about the y axis, in perspective.
    private var tiltTransform: CATransform3D {
      var perspective = CATransform3DIdentity
      perspective.m34 = -1 / Constants.perspectiveDistance
      return CATransform3DRotate(perspective, tilt * .pi / 180, 0, 1, 0)
    }

    /// The rotation of the scrolling rows, which follows the rotation within a small angle, so that neighboring rows don't
    /// overlap however far the rotation goes.
    private var rowRotation: CATransform3D {
      CATransform3DMakeRotation(Constants.maxRowAngle * sin(angle * .pi / 180) * .pi / 180, 0, 0, 1)
    }

    private var resizeTileSize: CGSize {
      CGSize(width: isWide ? Constants.wideTileWidth : Constants.tileSize.width, height: Constants.tileSize.height)
    }

    // MARK: - Constants

    private enum Constants {

      /// The step of the "Rotate" and "Tilt" controls, in degrees.
      static let angleStep: CGFloat = 30

      /// The scales that the "Scale" control cycles through.
      static let scales: [CGFloat] = [1, 1.3, 0.7]

      /// The skew factor at a quarter turn.
      static let maxSkew: CGFloat = 0.5

      /// The distance from the viewer to the 3D tile, which sets the strength of its perspective.
      static let perspectiveDistance: CGFloat = 200

      /// The largest rotation of the scrolling rows, in degrees.
      static let maxRowAngle: CGFloat = 6

      static let timing = AnimationTiming.easeInEaseOut(duration: 0.5)

      static let padding: CGFloat = 16
      static let sectionSpacing: CGFloat = 36
      static let titleSpacing: CGFloat = 12
      static let titleFontSize: CGFloat = 13
      static let captionSpacing: CGFloat = 20
      static let captionFontSize: CGFloat = 11
      static let labelFontSize: CGFloat = 14

      static let tileSize = CGSize(width: 72, height: 40)
      static let wideTileWidth: CGFloat = 140
      static let tileSpacing: CGFloat = 40
      static let anchorDotSize: CGFloat = 6

      static let stackItemSize: CGFloat = 32
      static let stackSpacing: CGFloat = 12

      static let cornerRadius: CGFloat = 10
      static let borderWidth: CGFloat = 2
      static let shadowOpacity: CGFloat = 0.35
      static let shadowRadius: CGFloat = 6
      static let shadowOffset = CGSize(width: 0, height: 4)
      static let opacity: CGFloat = 0.5
      static let badgeHorizontalPadding: CGFloat = 10
      static let badgeVerticalPadding: CGFloat = 4

      static let rowCount = 30
      static let rowSize = CGSize(width: 200, height: 32)
      static let rowSpacing: CGFloat = 12
      static let rowCornerRadius: CGFloat = 6
      static let listHeight: CGFloat = 180

      static let prerenderedSize = CGSize(width: 300, height: 88)

      static let buttonWidth: CGFloat = 76
      static let wideButtonWidth: CGFloat = 104
      static let buttonHeight: CGFloat = 32
      static let buttonFontSize: CGFloat = 13
      static let controlSpacing: CGFloat = 8
    }
  }
}
