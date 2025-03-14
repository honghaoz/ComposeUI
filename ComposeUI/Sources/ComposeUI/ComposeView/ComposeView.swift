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

  /// The ids of the renderable items that are being rendered.
  private var renderableItemIds: [String] = []

  /// The map of the renderable items that are being rendered.
  private var renderableItemMap: [String: RenderableItem] = [:]

  /// The map of the renderables that are being rendered.
  private var renderableMap: [String: Renderable] = [:]

  /// The map of the renderables that are being removed.
  ///
  /// The removing renderables are the ones that are not in the renderable hierarchy but still rendered due to the transition.
  private var removingRenderableMap: [String: Renderable] = [:]

  /// The map of the removing renderable transition completion blocks.
  private var removingRenderableTransitionCompletionMap: [String: CancellableBlock] = [:]

  // MARK: - Initialization

  /// Creates a `ComposeView` with the given content.
  ///
  /// - Parameter content: The content builder block. It passes in the content view that renders the content.
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
  /// - Parameter content: The content builder block. It passes in the content view that renders the content.
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

    // get renderable items
    let renderableItems: [RenderableItem]
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

      renderableItems = mappedChildItems
      contentSize = adjustedContentSize
    } else {
      renderableItems = contentNode.renderableItems(in: visibleBounds)
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

    // set up the renderable item ids and map
    let oldRenderableItemIds = renderableItemIds
    let oldRenderableItemMap = renderableItemMap
    let oldRenderableMap = renderableMap

    renderableItemIds = []
    renderableItemIds.reserveCapacity(oldRenderableItemIds.count + renderableItems.count) // TODO: check if this is correct
    renderableItemMap = [:]
    renderableItemMap.reserveCapacity(oldRenderableItemMap.count + renderableItems.count)
    renderableMap = [:]
    renderableMap.reserveCapacity(oldRenderableMap.count + renderableItems.count)

    for item in renderableItems {
      let id = item.id.id
      assert(renderableItemMap[id] == nil, "conflicting renderable item id: \(id)")
      renderableItemIds.append(id)
      renderableItemMap[id] = item
    }

    // update the renderables
    var reusingIds: Set<String> = []

    for oldId in oldRenderableItemIds {
      if renderableItemMap[oldId] == nil {
        // [1/3] 🗑️ remove the renderable item that are no longer in the content
        if let oldRenderableItem = oldRenderableItemMap[oldId], let oldRenderable = oldRenderableMap[oldId] {
          let oldFrame = oldRenderable.frame
          oldRenderableItem.willRemove?(oldRenderable, RenderableRemoveContext(oldFrame: oldFrame))

          let removeBlock = {
            oldRenderable.removeFromParent()
            oldRenderableItem.didRemove?(oldRenderable, RenderableRemoveContext(oldFrame: oldFrame))
          }

          if context.isAnimated, let transition = oldRenderableItem.transition?.remove {
            // if theres a remove transition, it can take time to complete, we need to track the old renderable until the
            // transition is completed because the renderable may be re-inserted into the renderable hierarchy later
            removingRenderableMap[oldId] = oldRenderable

            let completion = CancellableBlock { [weak self] in
              assert(Thread.isMainThread, "remove transition completion must be called on the main thread")
              guard let self else {
                return
              }

              self.removingRenderableMap.removeValue(forKey: oldId)
              self.removingRenderableTransitionCompletionMap.removeValue(forKey: oldId)

              removeBlock()
            } cancel: { [weak self] in
              guard let self else {
                return
              }
              self.removingRenderableMap.removeValue(forKey: oldId)
              self.removingRenderableTransitionCompletionMap.removeValue(forKey: oldId)
            }

            removingRenderableTransitionCompletionMap[oldId] = completion

            transition.animate(
              renderable: oldRenderable,
              context: RenderableTransition.RemoveTransition.Context(contentView: self),
              completion: completion.execute
            )
          } else {
            removeBlock()
          }
        } else {
          assertionFailure("old renderable item or old renderable not found: \(oldId)")
        }
      } else {
        // this renderable item is still in the content, plan to reuse it
        reusingIds.insert(oldId)
      }
    }

    for id in renderableItemIds {
      let renderableItem = renderableItemMap[id]! // swiftlint:disable:this force_unwrapping

      let renderable: Renderable
      if reusingIds.contains(id) {
        // [2/3] ♻️ reuse the renderable item that is still in the content
        renderable = oldRenderableMap[id]! // swiftlint:disable:this force_unwrapping

        // TODO: handle mismatched view/layer item

        renderable.layer.reset()

        let updateType: RenderableUpdateType
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

        let oldFrame = renderable.frame
        let newFrame = renderableItem.frame.rounded(scaleFactor: contentScaleFactor)

        let animationTiming: AnimationTiming?
        let animationContext: RenderableUpdateContext.AnimationContext?
        if context.isAnimated, let renderableItemAnimationTiming = renderableItem.animationTiming {
          animationTiming = renderableItemAnimationTiming
          animationContext = RenderableUpdateContext.AnimationContext(timing: renderableItemAnimationTiming, contentView: self)
        } else {
          animationTiming = nil
          animationContext = nil
        }

        let renderableUpdateContext = RenderableUpdateContext(
          type: updateType,
          oldFrame: oldFrame,
          newFrame: newFrame,
          animationContext: animationContext
        )

        renderableItem.willUpdate?(renderable, renderableUpdateContext)

        renderable.moveToFront()

        if let animationTiming {
          renderable.layer.animateFrame(to: newFrame, timing: animationTiming)
        } else {
          CATransaction.disableAnimations {
            renderable.setFrame(newFrame)
          }
        }

        renderableItem.update(renderable, renderableUpdateContext)

      } else {
        // [3/3] 🆕 insert the renderable item that is new
        let newFrame = renderableItem.frame.rounded(scaleFactor: contentScaleFactor)

        if let removingRenderable = removingRenderableMap[id] {
          // found a matching removing renderable, should add it back to the renderable hierarchy
          removingRenderableTransitionCompletionMap[id]?.cancel() // cancel the remove transition's completion
          removingRenderableMap.removeValue(forKey: id)
          removingRenderableTransitionCompletionMap.removeValue(forKey: id)
          renderable = removingRenderable
          // TODO: add tests for re-inserting removing renderable
        } else {
          renderable = CATransaction.disableAnimations { // no animation context for making new renderables
            renderableItem.make(RenderableMakeContext(initialFrame: newFrame))
          }
        }

        renderable.layer.reset()

        let frameBeforeWillInsert = renderable.frame
        renderableItem.willInsert?(renderable, RenderableInsertContext(oldFrame: frameBeforeWillInsert, newFrame: newFrame))
        let frameAfterWillInsert = renderable.frame

        let renderableUpdateContext = RenderableUpdateContext(
          type: .insert,
          oldFrame: frameAfterWillInsert,
          newFrame: newFrame,
          animationContext: nil // no animation context for insertion
        )

        renderableItem.willUpdate?(renderable, renderableUpdateContext)

        renderable.addToParent(contentView())

        CATransaction.disableAnimations {
          renderable.setFrame(newFrame) // no animation context for insertion
        }

        renderableItem.update(renderable, renderableUpdateContext)

        let renderableInsertContext = RenderableInsertContext(oldFrame: frameAfterWillInsert, newFrame: newFrame)
        if context.isAnimated, let transition = renderableItem.transition?.insert {
          // has insert transition, animate the renderable insertion
          transition.animate(
            renderable: renderable,
            context: RenderableTransition.InsertTransition.Context(targetFrame: newFrame, contentView: self),
            completion: {
              assert(Thread.isMainThread, "insert transition completion must be called on the main thread")
              // at the moment, the renderable's frame may not be the target frame, this is because during the insert transition,
              // the renderable can be refreshed, and the renderable's frame may be updated to a different frame.
              //
              // insert: [-------------------] setting frame to frame1
              // reuse:        [-----]         during the insert transition, the renderable's frame is updated to frame2
              renderableItem.didInsert?(renderable, renderableInsertContext)
            }
          )
        } else {
          // no insert transition, just call did insert
          renderableItem.didInsert?(renderable, renderableInsertContext)
        }
      }

      renderableMap[id] = renderable
    }
  }
}

// MARK: - Helpers

private extension CALayer {

  /// Common reset for the layer managed by `ComposeView`.
  ///
  /// To ensure the frame update is applied correctly, the transform is reset to identity.
  func reset() {
    disableActions(for: "transform") {
      transform = CATransform3DIdentity // setting frame requires an identity transform
    }
  }
}
