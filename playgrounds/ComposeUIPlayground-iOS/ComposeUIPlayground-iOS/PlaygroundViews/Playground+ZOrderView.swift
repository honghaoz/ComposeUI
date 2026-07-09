//
//  Playground+ZOrderView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/7/26.
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

import UIKit
import ComposeUI

extension Playground {

  /// A demo of `ComposeView`'s z-order contract for mixed view and layer items.
  ///
  /// The scrollable list shows overlapping tiles that alternate between two kinds:
  /// - "L" tiles (warm colors) are **layer** items (`ColorNode` + a `CATextLayer` overlay).
  /// - "V" tiles (cool colors) are **view** items (`ViewNode`).
  ///
  /// The z-order contract:
  /// - Tiles always stack in the items order, regardless of kind: a later tile renders above an earlier tile.
  /// - `zIndex` lifts a tile into a higher stacking band: the "P" (pinned) tile has `.zIndex(1)`, so it
  ///   renders above every band-0 tile even though it sits early in the items order.
  ///
  /// Try:
  /// - Scroll away and back: tiles are removed and re-inserted, and the stacking order always holds —
  ///   a cross-kind flip would be a z-order bug.
  /// - Tap "Reverse tiles order": the tiles animate to reversed positions and the stacking follows the new
  ///   items order; the "P" tile stays on top throughout.
  final class ZOrderView: ComposeView {

    private var isReversed = false

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack(spacing: 0) {
        Spacer().height(12)

        Label("Overlapping tiles: \"L\" tiles are layer items, \"V\" tiles are view items. Tiles always stack in the items order, regardless of kind — scroll away and back, the order holds. The \"P\" tile is pinned above everything with .zIndex(1).")
          .font(.systemFont(ofSize: 12))
          .textColor(.secondaryLabel)
          .textAlignment(.left)
          .numberOfLines(0)
          .frame(width: .flexible, height: 60)
          .padding(horizontal: 16)

        Spacer().height(12)

        ButtonNode { state in
          switch state {
          case .pressed,
               .selected:
            ColorNode(Colors.darkBlueGray)
              .cornerRadius(8)
              .overlay {
                Label("Reverse tiles order").textColor(.white)
              }
          case .normal,
               .hovered,
               .disabled:
            ColorNode(Colors.blueGray)
              .cornerRadius(8)
              .overlay {
                Label("Reverse tiles order").textColor(.white)
              }
          }
        } onTap: { [weak self] in
          guard let self else {
            return
          }
          isReversed.toggle()
          refresh()
        }
        .frame(width: 200, height: 36)

        Spacer().height(24)

        VStack(spacing: -Constants.tileOverlap) {
          let tileIndices = isReversed ? Array((0 ..< Constants.tileCount).reversed()) : Array(0 ..< Constants.tileCount)
          for (position, tileIndex) in tileIndices.enumerated() {
            if tileIndex == Constants.pinnedTileIndex {
              // the pinned tile: `.zIndex(1)` lifts it into a higher stacking band, so it renders above
              // every band-0 tile even though it sits early in the items order.
              pinnedTile(position: position)
            } else {
              tile(tileIndex, position: position)
            }
          }
        }

        Spacer().height(44)
      }
    }

    /// Makes the pinned tile: a view tile lifted above all band-0 tiles with `.zIndex(1)`.
    ///
    /// - Parameter position: The tile's position in the list, which determines the tile's horizontal placement.
    @ComposeContentBuilder
    private func pinnedTile(position: Int) -> ComposeContent {
      let alignment = Constants.tileAlignments[position % Constants.tileAlignments.count]
      ViewNode<TileView>(
        update: { view, _ in
          view.backgroundColor = UIColor(hue: 0.32, saturation: 0.75, brightness: 0.75, alpha: 0.92)
          view.label.text = "P\(Constants.pinnedTileIndex) (zIndex: 1)"
        }
      )
      .frame(width: Constants.tileWidth, height: Constants.tileHeight)
      .frame(width: .flexible, height: Constants.tileHeight, alignment: alignment)
      .zIndex(1)
      .fixedId("tile-\(Constants.pinnedTileIndex)")
    }

    /// Makes an overlapping tile.
    ///
    /// - Parameters:
    ///   - index: The tile index, which determines the tile's kind (even: layer, odd: view) and color.
    ///   - position: The tile's position in the list, which determines the tile's horizontal placement.
    @ComposeContentBuilder
    private func tile(_ index: Int, position: Int) -> ComposeContent {
      let alignment = Constants.tileAlignments[position % Constants.tileAlignments.count]
      if index.isMultiple(of: 2) {
        // a layer tile: the background and the text are both layer items
        ColorNode(Self.tileColor(index: index))
          .cornerRadius(Constants.tileCornerRadius)
          .border(color: UIColor.white.withAlphaComponent(0.6), width: 1)
          .overlay {
            LayerNode<CATextLayer>(
              make: { _ in
                let textLayer = CATextLayer()
                textLayer.font = Constants.tileFont
                textLayer.fontSize = Constants.tileFont.pointSize
                textLayer.alignmentMode = .center
                textLayer.contentsScale = UIScreen.main.scale
                return textLayer
              },
              update: { textLayer, _ in
                textLayer.string = "L\(index)"
                textLayer.foregroundColor = UIColor.white.cgColor
              }
            )
            .frame(width: .flexible, height: Constants.tileFont.lineHeight)
          }
          .frame(width: Constants.tileWidth, height: Constants.tileHeight)
          .frame(width: .flexible, height: Constants.tileHeight, alignment: alignment)
          .fixedId("tile-\(index)")
      } else {
        // a view tile
        ViewNode<TileView>(
          update: { view, _ in
            view.backgroundColor = Self.tileColor(index: index)
            view.label.text = "V\(index)"
          }
        )
        .frame(width: Constants.tileWidth, height: Constants.tileHeight)
        .frame(width: .flexible, height: Constants.tileHeight, alignment: alignment)
        .fixedId("tile-\(index)")
      }
    }

    /// The tile's color: warm colors for layer tiles, cool colors for view tiles, darker for later tiles.
    private static func tileColor(index: Int) -> UIColor {
      let progress = CGFloat(index) / CGFloat(max(1, Constants.tileCount - 1))
      if index.isMultiple(of: 2) {
        return UIColor(hue: 0.02 + 0.08 * progress, saturation: 0.85, brightness: 0.95 - 0.35 * progress, alpha: 0.92)
      } else {
        return UIColor(hue: 0.55 + 0.12 * progress, saturation: 0.8, brightness: 0.95 - 0.35 * progress, alpha: 0.92)
      }
    }

    // MARK: - Constants

    private enum Constants {
      static let tileCount = 30
      static let pinnedTileIndex = 3
      static let tileWidth: CGFloat = 200
      static let tileHeight: CGFloat = 56
      static let tileOverlap: CGFloat = 24
      static let tileCornerRadius: CGFloat = 10
      static let tileFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .bold)
      static let tileAlignments: [Layout.Alignment] = [.left, .center, .right, .center]
    }
  }
}

// MARK: - TileView

/// A view tile with a centered label.
private final class TileView: UIView {

  let label = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)

    layer.cornerRadius = 10
    layer.cornerCurve = .continuous
    layer.borderWidth = 1
    layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor

    label.font = .monospacedSystemFont(ofSize: 14, weight: .bold)
    label.textColor = .white
    label.textAlignment = .center
    addSubview(label)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    label.frame = bounds
  }
}
