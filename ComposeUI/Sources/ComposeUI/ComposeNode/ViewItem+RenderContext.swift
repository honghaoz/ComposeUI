//
//  ViewItem+RenderContext.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
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

// MARK: - Make

/// The context for making a view.
public struct ViewMakeContext {

  /// The initial frame of the new view if has one.
  public let initialFrame: CGRect?
}

// MARK: - Insert

/// The context for inserting a view into a view hierarchy.
public struct ViewInsertContext {

  /// The old frame of the view before it is inserted.
  public let oldFrame: CGRect

  /// The new frame that the view should be set to after the insertion.
  public let newFrame: CGRect
}

// MARK: - Update

/// The view update type.
public enum ViewUpdateType {

  /// The view is inserted into a view hierarchy.
  case insert

  /// The view is reused because of a refresh.
  case refresh

  /// The view is reused because of a scroll (origin changed).
  case scroll

  /// The view is reused because of a size change.
  case sizeChange

  /// The view is reused because of a bounds change (both size and origin are changed).
  case boundsChange

  // TODO: support more efficient update for scroll/bounds change
  // idea: could add a flag to indicate if the view requires full refresh on scroll/bounds change, for most of the case
  // this is not needed.
}

public struct ViewUpdateContext {

  /// The update type.
  public let type: ViewUpdateType

  /// The old frame of the view before the update.
  public let oldFrame: CGRect

  /// The new frame that the view should be set to after the update.
  public let newFrame: CGRect

  /// The animation context if the update is animated.
  public let animationContext: ViewAnimationContext?
}

// MARK: - Remove

/// The context for removing a view from a view hierarchy.
public struct ViewRemoveContext {

  /// The frame of the view before it is removed.
  public let oldFrame: CGRect
}
