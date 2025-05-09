//
//  RenderItem+Context.swift
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

/// The context for making a renderable.
public struct RenderableMakeContext {

  /// The initial frame of the new renderable if has one.
  public let initialFrame: CGRect?

  /// The content view that contains the renderable.
  public private(set) weak var contentView: ComposeView?
}

// MARK: - Insert

/// The context for inserting a renderable into a renderable hierarchy.
public struct RenderableInsertContext {

  /// The old frame of the renderable before it is inserted.
  public let oldFrame: CGRect

  /// The new frame that the renderable should be set to after the insertion.
  public let newFrame: CGRect

  /// The content view that contains the renderable.
  public private(set) weak var contentView: ComposeView!
}

// MARK: - Update

/// The renderable update type.
public enum RenderableUpdateType {

  /// The renderable is inserted into a renderable hierarchy.
  case insert

  /// The renderable is reused because the content view is refreshed explicitly.
  case refresh

  /// The renderable is reused because the content view is scrolled, i.e. the size is the same but the origin is changed.
  case scroll

  /// The renderable is reused because the content view's bounds are changed, i.e. the size is changed.
  case boundsChange

  /// Whether the update requires a full update, i.e. the renderable inserted or explicitly refreshed.
  public var requiresFullUpdate: Bool {
    switch self {
    case .insert,
         .refresh:
      return true
    case .scroll,
         .boundsChange:
      return false
    }
  }
}

public struct RenderableUpdateContext {

  /// The update type.
  public let updateType: RenderableUpdateType

  /// The old frame of the renderable before the update.
  public let oldFrame: CGRect

  /// The new frame that the renderable should be set to after the update.
  public let newFrame: CGRect

  /// The animation context if the update is animated.
  public let animationTiming: AnimationTiming?

  /// The content view that contains the renderable.
  public private(set) weak var contentView: ComposeView!
}

// MARK: - Remove

/// The context for removing a renderable from a renderable hierarchy.
public struct RenderableRemoveContext {

  /// The frame of the renderable before it is removed.
  public let oldFrame: CGRect

  /// The content view that contains the renderable.
  public private(set) weak var contentView: ComposeView!
}
