//
//  ComposeView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

/// A view that renders `ComposeContent`.
open class ComposeView: BaseScrollView {

  /// The content for the view.
  ///
  /// This is overridable so that a subclass can provide a content.
  ///
  /// A typical example of a `ComposeView` subclass:
  ///
  /// ```swift
  /// class MyView: ComposeView {
  ///
  ///   @ComposeContentBuilder
  ///   override var content: ComposeContent {
  ///     VStack {
  ///       Text("Hello, World!")
  ///     }
  ///   }
  /// }
  /// ```
  open var content: ComposeContent {
    Empty()
  }

  /// The block to make content.
  private var makeContent: (ComposeView) -> ComposeContent

  /// The current content node that the view is rendering.
  private var contentNode: ContentNode?

  /// The context of the current content update.
  private var contentUpdateContext: ContentUpdateContext?

  /// The bounds used for last render pass.
  private lazy var lastRenderBounds: CGRect = .zero

  /// The ids of the view items that the view is rendering.
  private var viewItemIds: [String] = []

  /// The map of the view items that the view is rendering.
  private var viewItemMap: [String: ViewItem<View>] = [:]

  /// The map of the views that the view is rendering.
  private var viewMap: [String: View] = [:]

  /// The map of the views that are being removed.
  ///
  /// The removing views are the ones that are not in the view hierarchy but still rendered due to the transition.
  private var removingViewMap: [String: View] = [:]

  /// The map of the removing view transition completion blocks.
  private var removingViewTransitionCompletionMap: [String: CancellableBlock] = [:]

  // MARK: - Initialization

  /// Creates a `ComposeView` with the given content.
  ///
  /// - Parameter content: The content builder block. It passes in the view that renders the content.
  public init(@ComposeContentBuilder content: @escaping (ComposeView) -> ComposeContent) {
    self.makeContent = content

    super.init(frame: .zero)

    commonInit()
  }

  /// Creates a `ComposeView` with the given content.
  ///
  /// - Parameter content: The content builder block.
  public init(@ComposeContentBuilder content: @escaping () -> ComposeContent) {
    makeContent = { _ in content() }

    super.init(frame: .zero)

    commonInit()
  }

  /// Creates a `ComposeView` with the given content.
  ///
  /// - Parameter content: The content.
  public convenience init(content: ComposeContent) {
    self.init { content }
  }

  /// Creates a blank `ComposeView`.
  ///
  /// You should either override `content` to provide the actual content or use `setContent()` to set the content later.
  override public init(frame: CGRect) {
    makeContent = { _ in Empty() }

    super.init(frame: frame)

    makeContent = { [unowned self] _ in content } // swiftlint:disable:this unowned_variable
    commonInit()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  private func commonInit() {
    contentScaleFactor = screenScaleFactor

    #if canImport(UIKit)
    contentInsetAdjustmentBehavior = .never // ensure the content inset is consistent
    #endif
  }

  // MARK: - Content

  /// Set a new content.
  ///
  /// - Parameter content: The content builder block. It passes in the view that renders the content.
  func setContent(@ComposeContentBuilder content: @escaping (ComposeView) -> ComposeContent) {
    makeContent = content
  }

  /// Set a new content.
  ///
  /// - Parameter content: The content builder block.
  func setContent(@ComposeContentBuilder content: @escaping () -> ComposeContent) {
    makeContent = { _ in content() }
  }

  // MARK: - Size

  #if canImport(UIKit)
  /// Get the size that fits the content.
  ///
  /// - Parameter size: The container size.
  /// - Returns: The size that fits the content.
  override open func sizeThatFits(_ size: CGSize) -> CGSize {
    _sizeThatFits(size)
  }
  #else
  /// Get the size that fits the content.
  ///
  /// - Parameter size: The container size.
  /// - Returns: The size that fits the content.
  open func sizeThatFits(_ size: CGSize) -> CGSize {
    _sizeThatFits(size)
  }
  #endif

  private func _sizeThatFits(_ size: CGSize) -> CGSize {
    var contentNode = makeContent(self).asVStack(alignment: .center)
    _ = contentNode.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: contentScaleFactor))
    return contentNode.size.roundedUp(scaleFactor: contentScaleFactor)
  }

  // MARK: - Render

  /// Refreshes and re-renders the content.
  ///
  /// This call will make a new content from the builder block and re-render the content immediately.
  ///
  /// - Parameter animated: Whether the refresh is animated.
  public func refresh(animated: Bool = true) {
    assert(Thread.isMainThread, "refresh must be called on the main thread")

    // explicit render request, should make a new content
    contentNode = ContentNode(node: makeContent(self).asVStack(alignment: .center))
    contentUpdateContext = ContentUpdateContext(updateType: .refresh(isAnimated: animated))

    render()
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    if contentUpdateContext == nil, bounds() != lastRenderBounds {
      // no pending render request but the bounds changed, should re-render the content
      if contentNode == nil {
        contentNode = ContentNode(node: makeContent(self).asVStack(alignment: .center))
      }
      contentUpdateContext = ContentUpdateContext(updateType: .boundsChange(previousBounds: lastRenderBounds))
    }

    render()
  }

  /// Performs a render pass.
  open func render() {
    assert(Thread.isMainThread, "render must be called on the main thread")

    guard var contentUpdateContext, !contentUpdateContext.isRendering else {
      return
    }

    contentUpdateContext.isRendering = true
    self.contentUpdateContext = contentUpdateContext

    render(contentUpdateContext)

    self.contentUpdateContext = nil
    lastRenderBounds = bounds()
  }

  private func render(_ context: ContentUpdateContext) {
    guard let contentNode else {
      return
    }

    // do the layout
    _ = contentNode.layout(containerSize: bounds().size, context: ComposeNodeLayoutContext(scaleFactor: contentScaleFactor))

    // TODO: check if the content is larger than the container
    // if not, should use frame to center the content

    setContentSize(contentNode.size.roundedUp(scaleFactor: contentScaleFactor))

    let viewItems = contentNode.viewItems(in: bounds())

    // set up the view item ids and map
    let oldViewItemIds = viewItemIds
    let oldViewItemMap = viewItemMap
    let oldViewMap = viewMap

    viewItemIds = []
    viewItemIds.reserveCapacity(oldViewItemIds.count + viewItems.count)
    viewItemMap = [:]
    viewItemMap.reserveCapacity(oldViewItemMap.count + viewItems.count)
    viewMap = [:]
    viewMap.reserveCapacity(oldViewMap.count + viewItems.count)

    for viewItem in viewItems {
      let id = viewItem.id.id
      viewItemIds.append(id)
      assert(viewItemMap[id] == nil, "conflicting view item id: \(id)")
      viewItemMap[id] = viewItem
    }

    // update the views
    var reusingIds: Set<String> = []

    for oldId in oldViewItemIds {
      if viewItemMap[oldId] == nil {
        // [1/3] 🗑️ remove the view item that are no longer in the content
        if let oldViewItem = oldViewItemMap[oldId], let oldView = oldViewMap[oldId] {
          let oldFrame = oldView.frame
          oldViewItem.willRemove?(oldView, ViewRemoveContext(oldFrame: oldFrame))

          let removeBlock = {
            oldView.removeFromSuperview()
            oldViewItem.didRemove?(oldView, ViewRemoveContext(oldFrame: oldFrame))
          }

          if context.isAnimated, let transition = oldViewItem.transition?.remove {
            // if theres a remove transition, it can take time to complete, we need to track the old view until the
            // transition is completed because the view may be re-inserted into the view hierarchy later
            removingViewMap[oldId] = oldView

            let completion = CancellableBlock { [weak self] in
              assert(Thread.isMainThread, "remove transition completion must be called on the main thread")
              guard let self else {
                return
              }

              self.removingViewMap.removeValue(forKey: oldId)
              self.removingViewTransitionCompletionMap.removeValue(forKey: oldId)

              removeBlock()
            } cancel: { [weak self] in
              guard let self else {
                return
              }
              self.removingViewMap.removeValue(forKey: oldId)
              self.removingViewTransitionCompletionMap.removeValue(forKey: oldId)
            }

            removingViewTransitionCompletionMap[oldId] = completion

            transition.animate(view: oldView, context: ViewRemoveTransitionContext(contentView: self), completion: completion)
          } else {
            removeBlock()
          }
        } else {
          assertionFailure("old view item or old view not found: \(oldId)")
        }
      } else {
        // this view item is still in the content, plan to reuse it
        reusingIds.insert(oldId)
      }
    }

    for id in viewItemIds {
      let viewItem = viewItemMap[id]! // swiftlint:disable:this force_unwrapping

      let view: View
      if reusingIds.contains(id) {
        // [2/3] ♻️ reuse the view item that is still in the content
        view = oldViewMap[id]! // swiftlint:disable:this force_unwrapping

        view.reset()

        let updateType: ViewUpdateType
        switch context.updateType {
        case .refresh:
          updateType = .refresh
        case .boundsChange(let previousBounds):
          if previousBounds.size == bounds.size {
            updateType = .scroll
          } else if previousBounds.origin == bounds.origin {
            updateType = .sizeChange
          } else {
            updateType = .boundsChange
          }
        }

        let oldFrame = view.frame
        let newFrame = viewItem.frame.rounded(scaleFactor: contentScaleFactor)

        let animation: ViewAnimation?
        let animationContext: ViewAnimationContext?
        if context.isAnimated, let viewAnimation = viewItem.animation {
          animation = viewAnimation
          animationContext = ViewAnimationContext(timing: viewAnimation.timing, contentView: self)
        } else {
          animation = nil
          animationContext = nil
        }

        let viewUpdateContext = ViewUpdateContext(
          type: updateType,
          oldFrame: oldFrame,
          newFrame: newFrame,
          animationContext: animationContext
        )

        viewItem.willUpdate?(view, viewUpdateContext)

        contentView().bringSubviewToFront(view)

        if let animationTiming = animation?.timing {
          view.layer().animateFrame(to: newFrame, timing: animationTiming)
        } else {
          view.frame = newFrame
        }

        viewItem.update(view, viewUpdateContext)

      } else {
        // [3/3] 🆕 insert the view item that is new
        let newFrame = viewItem.frame.rounded(scaleFactor: contentScaleFactor)

        if let removingView = removingViewMap[id] {
          // found a matching removing view, should add it back to the view hierarchy
          removingViewTransitionCompletionMap[id]?.cancel() // cancel the remove transition's completion
          removingViewMap.removeValue(forKey: id)
          removingViewTransitionCompletionMap.removeValue(forKey: id)
          view = removingView
          // TODO: add tests for re-inserting removing view
        } else {
          view = CATransaction.disableAnimations { // no animation context for making new views
            viewItem.make(ViewMakeContext(initialFrame: newFrame))
          }
        }

        view.reset()

        let frameBeforeWillInsert = view.frame
        viewItem.willInsert?(view, ViewInsertContext(oldFrame: frameBeforeWillInsert, newFrame: newFrame))
        let frameAfterWillInsert = view.frame

        contentView().addSubview(view)

        let didInsertBlock = {
          viewItem.didInsert?(view, ViewInsertContext(oldFrame: frameAfterWillInsert, newFrame: newFrame))

          let viewUpdateContext = ViewUpdateContext(
            type: .insert,
            oldFrame: frameAfterWillInsert,
            newFrame: newFrame,
            animationContext: nil // no animation context for insertion
          )
          viewItem.update(view, viewUpdateContext)
        }

        if context.isAnimated, let transition = viewItem.transition?.insert {
          // has insert transition, animate the view insertion
          transition.animate(
            view: view,
            context: ViewInsertTransitionContext(targetFrame: newFrame, contentView: self),
            completion: CancellableBlock {
              assert(Thread.isMainThread, "insert transition completion must be called on the main thread")
              // at the moment, the view's frame may not be the target frame, this is because during the insert transition,
              // the view can be refreshed, and the view's frame may be updated to a different frame.
              //
              // insert: [-------------------] setting frame to frame1
              // reuse:        [-----]         during the insert transition, the view's frame is updated to frame2
              didInsertBlock()
            }
          )
        } else {
          // no insert transition, just set the frame and update without animation
          view.frame = newFrame
          didInsertBlock()
        }
      }

      viewMap[id] = view
    }
  }
}

// MARK: - Helpers

private extension View {

  /// Common reset for the view managed by `ComposeView`.
  ///
  /// To ensure the frame update is applied correctly, the transform is reset to identity.
  func reset() {
    CATransaction.disableAnimations {
      layer().transform = CATransform3DIdentity // setting frame requires an identity transform
    }
  }
}
