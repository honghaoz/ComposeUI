//
//  ComposeView+AnimationBehavior.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/13/26.
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

import Foundation

public extension ComposeView {

  /// The animation behavior of the ComposeView's content update.
  enum AnimationBehavior {

    /// The default animation behavior.
    ///
    /// - Refreshes (`refresh(animated:)` and `setNeedsRefresh(animated:)`): Transitions and animations follow their `animated` flag.
    /// - Bounds change (resize or scroll): Transitions are enabled, but animations are disabled.
    case `default`

    /// The transitions and animations are disabled.
    case disabled

    /// The dynamic animation behavior.
    ///
    /// The closure is called once per render pass and determines whether the transitions and animations are enabled.
    ///
    /// Note: For render type `boundsChange`, returning `true` will also animate the reused renderables' updates, so
    /// their frame can lag behind scrolling and live resizing.
    case dynamic(_ shouldAnimate: (_ contentView: ComposeView, _ renderType: RenderType) -> Bool)
  }
}
