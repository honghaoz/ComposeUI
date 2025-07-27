//
//  RenderableTransition.swift
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

/// A model contains the view insert and remove transition.
public struct RenderableTransition {

  /// A transition for inserting a renderable into a content view.
  public struct InsertTransition {

    /// The context for the insert transition.
    public struct Context {

      /// The target frame of the renderable.
      public let targetFrame: CGRect

      /// The content view that the renderable is being inserted into.
      public private(set) weak var contentView: View!
    }

    private let animate: (Renderable, Context, @escaping () -> Void) -> Void

    /// Creates a new insert transition with the given animation closure.
    ///
    /// - Parameter animate: The closure to animate the insert transition.
    ///                      The closure provides the renderable to insert, the animation context, and the completion block.
    ///                      You must make sure to call the completion block when the transition is completed.
    ///                      You must make sure the renderable's frame is set to the target frame when the transition is completed.
    public init(animate: @escaping (_ renderable: Renderable, _ context: Context, _ completion: @escaping () -> Void) -> Void) {
      self.animate = animate
    }

    /// Animates the insert transition.
    ///
    /// - Parameters:
    ///   - renderable: The renderable to insert.
    ///   - context: The context for the insert transition.
    ///   - completion: The completion block to be called when the transition is completed.
    public func animate(renderable: Renderable, context: Context, completion: @escaping () -> Void) {
      animate(renderable, context, completion)
    }
  }

  /// A transition for removing a renderable from a content view.
  public struct RemoveTransition {

    /// The context for the remove transition.
    public struct Context {

      /// The content view that the renderable is being removed from.
      public private(set) weak var contentView: View!
    }

    private let animate: (Renderable, Context, @escaping () -> Void) -> Void

    /// Creates a new remove transition with the given animation closure.
    ///
    /// - Parameter animate: The closure to animate the remove transition.
    ///                      The closure provides the renderable to remove, the animation context, and the completion block.
    ///                      You must make sure to call the completion block when the transition is completed.
    public init(animate: @escaping (_ renderable: Renderable, _ context: Context, _ completion: @escaping () -> Void) -> Void) {
      self.animate = animate
    }

    /// Animates the remove transition.
    ///
    /// - Parameters:
    ///   - renderable: The renderable to remove.
    ///   - context: The context for the remove transition.
    ///   - completion: The completion block to be called when the transition is completed.
    public func animate(renderable: Renderable, context: Context, completion: @escaping () -> Void) {
      animate(renderable, context, completion)
    }
  }

  /// Options to control transition animations.
  public struct Options: OptionSet, Hashable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    /// Only animate the insertion transition.
    public static let insert = Options(rawValue: 1 << 0)

    /// Only animate the removal transition.
    public static let remove = Options(rawValue: 1 << 1)

    /// Animate both the insertion and removal transitions.
    public static let both: Options = [.insert, .remove]
  }

  /// The insert transition.
  public let insert: InsertTransition?

  /// The remove transition.
  public let remove: RemoveTransition?

  /// Creates a new renderable transition with the given insert and remove transitions.
  ///
  /// - Parameters:
  ///   - insert: The insert transition.
  ///   - remove: The remove transition.
  public init(insert: InsertTransition?, remove: RemoveTransition?) {
    self.insert = insert
    self.remove = remove
  }
}
