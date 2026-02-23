//
//  RenderItem+Context.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
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
public enum RenderableUpdateType: Equatable {

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

public struct RenderableUpdateContext: Equatable {

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
