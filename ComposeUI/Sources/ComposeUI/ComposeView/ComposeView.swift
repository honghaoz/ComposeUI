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

  /// The default content when the view is initialized with `init(frame:)`.
  ///
  /// A `ComposeView` subclass can override this property to provide a different content.
  /// For example:
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

  /// The insets to apply to the visible bounds when determining which content to render.
  ///
  /// - Negative values expand the visible bounds in that direction, causing more content to be rendered.
  /// - Positive values shrink the visible bounds in that direction, causing less content to be rendered.
  ///
  /// The default value is zero for all edges, which means the visible bounds are not adjusted.
  public var visibleBoundsInsets = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

  /// The bounds used for last render pass.
  private lazy var lastRenderBounds: CGRect = .zero

  /// The ids of the view items that the view is rendering.
  private var viewItemIds: [String] = []

  /// The map of the view items that the view is rendering.
  private var viewItemMap: [String: RenderableItem] = [:]

  /// The map of the views that the view is rendering.
  private var viewMap: [String: Renderable] = [:]

  /// The map of the views that are being removed.
  ///
  /// The removing views are the ones that are not in the view hierarchy but still rendered due to the transition.
  private var removingViewMap: [String: Renderable] = [:]

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

  /// Creates a `ComposeView` with `content` as the default content.
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

    #if canImport(AppKit)
    drawsBackground = false // make the view transparent
    #endif

    #if canImport(UIKit)
    // ensure the content inset is consistent regardless of the safe area
    contentInsetAdjustmentBehavior = .never
    #endif
  }

  // MARK: - Content

  /// Set a new content.
  ///
  /// - Parameter content: The content builder block. It passes in the view that renders the content.
  open func setContent(@ComposeContentBuilder content: @escaping (ComposeView) -> ComposeContent) {
    makeContent = content
  }

  /// Set a new content.
  ///
  /// - Parameter content: The content builder block.
  open func setContent(@ComposeContentBuilder content: @escaping () -> ComposeContent) {
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

  // MARK: - Scroll

  /// A flag to indicate if the `isScrollable` property is set explicitly.
  private var isScrollableExplicitlySet: Bool = false

  override public final var isScrollable: Bool {
    get {
      super.isScrollable
    }
    set {
      isScrollableExplicitlySet = true
      super.isScrollable = newValue
    }
  }

  // MARK: - Render

  /// Refreshes and re-renders the content.
  ///
  /// This call will make a new content from the builder block and re-render the content immediately.
  ///
  /// - Parameter animated: Whether the refresh is animated.
  open func refresh(animated: Bool = true) {
    assert(Thread.isMainThread, "refresh() must be called on the main thread")

    // explicit render request, should make a new content
    contentNode = ContentNode(node: makeContent(self).asVStack(alignment: .center))
    contentUpdateContext = ContentUpdateContext(updateType: .refresh(isAnimated: animated))

    render()
  }

  private var hasPendingRefresh: Bool = false

  /// Requests a refresh of the content.
  ///
  /// This method is non-blocking and will return immediately.
  /// The refresh will be performed on the next run loop iteration.
  ///
  /// - Parameter animated: Whether the refresh is animated.
  open func setNeedsRefresh(animated: Bool = true) {
    assert(Thread.isMainThread, "setNeedsRefresh() must be called on the main thread")

    guard !hasPendingRefresh else {
      return
    }

    hasPendingRefresh = true

    RunLoop.main.perform(inModes: [.common]) { [weak self] in
      guard let self else {
        return
      }

      self.hasPendingRefresh = false
      self.refresh(animated: animated)
    }
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    if contentUpdateContext == nil, bounds() != lastRenderBounds {
      // no pending render request but the bounds changed, should re-render the content
      contentNode = ContentNode(node: makeContent(self).asVStack(alignment: .center))
      contentUpdateContext = ContentUpdateContext(updateType: .boundsChange(previousBounds: lastRenderBounds))
    }

    render()
  }

  /// Performs a render pass.
  open func render() {
    assert(Thread.isMainThread, "render() must be called on the main thread")

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

    let bounds = bounds()
    let boundsSize = bounds.size
    let visibleBounds = bounds.inset(by: visibleBoundsInsets)

    // do the layout
    _ = contentNode.layout(containerSize: boundsSize, context: ComposeNodeLayoutContext(scaleFactor: contentScaleFactor))
    var contentSize = contentNode.size

    // get view items
    let viewItems: [RenderableItem]
    if contentSize.width < boundsSize.width || contentSize.height < boundsSize.height {
      // if content is smaller than the bounds in either dimension, should center the content

      let adjustedContentSize = CGSize(
        width: max(contentSize.width, boundsSize.width),
        height: max(contentSize.height, boundsSize.height)
      )

      // logic copied from FrameNode
      let childFrame = Layout.position(rect: contentSize, in: adjustedContentSize, alignment: .center)
      let boundsInChild = visibleBounds.translate(-childFrame.origin)
      let childItems = contentNode.renderableItems(in: boundsInChild)

      var mappedChildItems: [RenderableItem] = []
      mappedChildItems.reserveCapacity(childItems.count)

      for var item in childItems {
        item.frame = item.frame.translate(childFrame.origin)
        mappedChildItems.append(item)
      }

      viewItems = mappedChildItems
      contentSize = adjustedContentSize
    } else {
      viewItems = contentNode.renderableItems(in: visibleBounds)
    }

    // set content size
    setContentSize(contentSize.roundedUp(scaleFactor: contentScaleFactor))

    // adjust isScrollable based on content size if not set explicitly
    if !isScrollableExplicitlySet {
      if contentSize.width > boundsSize.width || contentSize.height > boundsSize.height {
        super.isScrollable = true
      } else {
        super.isScrollable = false
      }
    }

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
            oldView.removeFromParent()
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

            transition.animate(view: oldView, context: ViewRemoveTransitionContext(contentView: self), completion: completion.workBlock)
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

      let view: Renderable
      if reusingIds.contains(id) {
        // [2/3] ♻️ reuse the view item that is still in the content
        view = oldViewMap[id]! // swiftlint:disable:this force_unwrapping

        // TODO: handle mismatched view/layer item

        view.layer.reset()

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

        let animationTiming: AnimationTiming?
        let animationContext: ViewAnimationContext?
        if context.isAnimated, let viewItemAnimationTiming = viewItem.animationTiming {
          animationTiming = viewItemAnimationTiming
          animationContext = ViewAnimationContext(timing: viewItemAnimationTiming, contentView: self)
        } else {
          animationTiming = nil
          animationContext = nil
        }

        let viewUpdateContext = ViewUpdateContext(
          type: updateType,
          oldFrame: oldFrame,
          newFrame: newFrame,
          animationContext: animationContext
        )

        viewItem.willUpdate?(view, viewUpdateContext)

        view.moveToFront()

        if let animationTiming {
          view.layer.animateFrame(to: newFrame, timing: animationTiming)
        } else {
          CATransaction.disableAnimations {
            view.setFrame(newFrame)
          }
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

        view.layer.reset()

        let frameBeforeWillInsert = view.frame
        viewItem.willInsert?(view, ViewInsertContext(oldFrame: frameBeforeWillInsert, newFrame: newFrame))
        let frameAfterWillInsert = view.frame

        let viewUpdateContext = ViewUpdateContext(
          type: .insert,
          oldFrame: frameAfterWillInsert,
          newFrame: newFrame,
          animationContext: nil // no animation context for insertion
        )

        viewItem.willUpdate?(view, viewUpdateContext)

        view.addToParent(contentView())

        CATransaction.disableAnimations {
          view.setFrame(newFrame) // no animation context for insertion
        }

        viewItem.update(view, viewUpdateContext)

        let viewInsertContext = ViewInsertContext(oldFrame: frameAfterWillInsert, newFrame: newFrame)
        if context.isAnimated, let transition = viewItem.transition?.insert {
          // has insert transition, animate the view insertion
          transition.animate(
            view: view,
            context: ViewInsertTransitionContext(targetFrame: newFrame, contentView: self),
            completion: {
              assert(Thread.isMainThread, "insert transition completion must be called on the main thread")
              // at the moment, the view's frame may not be the target frame, this is because during the insert transition,
              // the view can be refreshed, and the view's frame may be updated to a different frame.
              //
              // insert: [-------------------] setting frame to frame1
              // reuse:        [-----]         during the insert transition, the view's frame is updated to frame2
              viewItem.didInsert?(view, viewInsertContext)
            }
          )
        } else {
          // no insert transition, just call did insert
          viewItem.didInsert?(view, viewInsertContext)
        }
      }

      viewMap[id] = view
    }
  }
}

// MARK: - Helpers

private extension CALayer {

  /// Common reset for the view managed by `ComposeView`.
  ///
  /// To ensure the frame update is applied correctly, the transform is reset to identity.
  func reset() {
    CATransaction.disableAnimations {
      transform = CATransform3DIdentity // setting frame requires an identity transform
    }
  }
}
