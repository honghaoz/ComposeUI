//
//  Playground+Pinstripes.swift
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

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

import ComposeUI

extension Playground {

  /// Tiles of `PinstripesNode`s: an Aqua window's stripes, vertical ones, fine ones and ones in colors of their own, in
  /// the light and dark themes.
  final class Pinstripes: ComposeView {

    /// The height that the view needs for the tiles and their titles.
    static let preferredHeight: CGFloat = 132

    @ComposeContentBuilder
    override var content: ComposeContent {
      HStack(spacing: Constants.tileSpacing) {
        Self.tile("Aqua") {
          PinstripesNode()
        }
        Self.tile("Vertical") {
          PinstripesNode(axis: .vertical)
        }
        Self.tile("Fine") {
          PinstripesNode(thickness: 1, spacing: 1)
        }
        Self.tile("Colored") {
          PinstripesNode(
            axis: .vertical,
            thickness: 6,
            spacing: 10,
            offset: 5,
            color: ThemedColor(light: Color(red: 0.85, green: 0.91, blue: 0.98, alpha: 1), dark: Color(red: 0.12, green: 0.2, blue: 0.3, alpha: 1))
          )
        }
      }
      .frame(width: .flexible, height: .flexible)
    }

    /// A tile of stripes with a title under it.
    private static func tile(_ title: String, @ComposeContentBuilder stripes: () -> ComposeContent) -> some ComposeNode {
      VStack(spacing: Constants.titleSpacing) {
        ZStack {
          stripes()
        }
        .frame(width: Constants.tileSize, height: Constants.tileSize)
        .overlay {
          LayerNode()
            .border(color: Color.gray, width: 1)
        }

        LabelNode(title)
          .font(.systemFont(ofSize: Constants.titleFontSize))
      }
    }

    // MARK: - Constants

    private enum Constants {

      /// The size of a tile, small enough for four tiles on an iPhone's width.
      static let tileSize: CGFloat = 76

      static let tileSpacing: CGFloat = 12
      static let titleSpacing: CGFloat = 6
      static let titleFontSize: CGFloat = 12
    }
  }
}
