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

/// The reason for a renderable update.
public enum RenderableUpdateType: Equatable {

  /// The renderable is inserted into a renderable hierarchy.
  case insert

  /// The renderable is reused after an explicit refresh request or environment-triggered content refresh.
  case refresh

  /// The renderable is reused after scrolling, resizing, or both, without refreshing its content.
  case boundsChange
}

public struct RenderableUpdateContext: Equatable {

  /// The reason for the update.
  public let updateType: RenderableUpdateType

  /// The old frame of the renderable before the update.
  ///
  /// The frame is read from the renderable, so it can differ from the frame the previous update applied by
  /// floating-point noise, for example on a 3x display. Compare it with `newFrame` with a tolerance rather than exactly.
  public let oldFrame: CGRect

  /// The new frame that the renderable should be set to after the update.
  public let newFrame: CGRect

  /// The content view's bounds from its last completed render, or nil before its first render.
  public let previousRenderBounds: CGRect?

  /// The content view's bounds used to select and position the renderables of this render pass, before applying `visibleBoundsInsets`.
  public let renderBounds: CGRect

  /// The timing to use for this renderable update, or nil to apply changes immediately.
  public let animationTiming: AnimationTiming?

  /// The content view that contains the renderable.
  public private(set) weak var contentView: ComposeView!

  /// The content evaluation of this render pass.
  let contentEvaluation: ContentEvaluation?

  /// Whether transitions and update animations are enabled for this render pass.
  let animationDecision: ComposeView.AnimationDecision

  /// Creates a renderable update context.
  ///
  /// - Parameters:
  ///   - updateType: The reason for the update.
  ///   - oldFrame: The old frame of the renderable before the update.
  ///   - newFrame: The new frame that the renderable should be set to after the update.
  ///   - previousRenderBounds: The content view's last completed render bounds, or nil if it has not rendered.
  ///   - renderBounds: The content view's bounds used for this render pass.
  ///   - animationTiming: The timing to use for this renderable update, or nil to apply changes immediately.
  ///   - contentView: The content view that contains the renderable.
  ///   - contentEvaluation: The content evaluation of this render pass.
  ///   - animationDecision: Whether transitions and update animations are enabled.
  init(updateType: RenderableUpdateType,
       oldFrame: CGRect,
       newFrame: CGRect,
       previousRenderBounds: CGRect?,
       renderBounds: CGRect,
       animationTiming: AnimationTiming?,
       contentView: ComposeView?,
       contentEvaluation: ContentEvaluation?,
       animationDecision: ComposeView.AnimationDecision)
  {
    self.updateType = updateType
    self.oldFrame = oldFrame
    self.newFrame = newFrame
    self.previousRenderBounds = previousRenderBounds
    self.renderBounds = renderBounds
    self.animationTiming = animationTiming
    self.contentView = contentView
    self.contentEvaluation = contentEvaluation
    self.animationDecision = animationDecision
  }

  // MARK: - Equatable

  public static func == (lhs: Self, rhs: Self) -> Bool {
    // ignore internal properties that are not part of the public contract:
    // - contentEvaluation
    // - animationDecision
    lhs.updateType == rhs.updateType &&
      lhs.oldFrame == rhs.oldFrame &&
      lhs.newFrame == rhs.newFrame &&
      lhs.previousRenderBounds == rhs.previousRenderBounds &&
      lhs.renderBounds == rhs.renderBounds &&
      lhs.animationTiming == rhs.animationTiming &&
      lhs.contentView == rhs.contentView
  }
}

// MARK: - Remove

/// The context for removing a renderable from a renderable hierarchy.
public struct RenderableRemoveContext {

  /// The frame of the renderable before it is removed.
  public let oldFrame: CGRect

  /// The content view that contains the renderable.
  public private(set) weak var contentView: ComposeView!
}
