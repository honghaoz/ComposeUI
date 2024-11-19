//
//  ViewItem+Transition.swift
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

// MARK: - View Transition

/// A model contains the view insert and remove transition.
public struct ViewTransition {

  /// The insert transition.
  public let insert: ViewInsertTransition?

  /// The remove transition.
  public let remove: ViewRemoveTransition?
}

// MARK: - View Insert Transition

/// The context for inserting a view into a view hierarchy with a transition animation.
public struct ViewInsertTransitionContext {

  /// The target frame of the view.
  public let targetFrame: CGRect

  /// The content view that the view is being inserted into.
  public private(set) weak var contentView: ComposeView!
}

public protocol ViewInsertTransition {

  /// Animates the view insertion.
  ///
  /// The view's frame is set to the target frame with style updated before the animation starts.
  ///
  /// - Parameters:
  ///   - view: The view to insert.
  ///   - context: The context for the insert transition.
  ///   - completion: The completion block to be called when the transition is completed.
  ///                 You must make sure to call the completion block when the transition is completed.
  ///                 You must make sure the view's frame is set to the target frame when the transition is completed.
  func animate(view: View, context: ViewInsertTransitionContext, completion: @escaping () -> Void)
}

// MARK: - View Remove Transition

/// The context for removing a view from a view hierarchy with a transition animation.
public struct ViewRemoveTransitionContext {

  /// The content view that the view is being removed from.
  public private(set) weak var contentView: ComposeView!
}

public protocol ViewRemoveTransition {

  /// Animates the view removal.
  ///
  /// - Parameters:
  ///   - view: The view to remove.
  ///   - context: The context for the remove transition.
  ///   - completion: The completion block to be called when the transition is completed.
  ///                 You must make sure to call the completion block when the transition is completed.
  func animate(view: View, context: ViewRemoveTransitionContext, completion: @escaping () -> Void)
}
