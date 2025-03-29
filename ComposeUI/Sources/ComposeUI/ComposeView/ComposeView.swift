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

import Combine

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

  // MARK: - Animation Behavior

  /// The type of the render pass.
  public enum RenderType {

    /// The content is explicitly refreshed.
    case refresh(isAnimated: Bool)

    /// The content is scrolled, i.e. the size is the same but the origin is changed.
    case scroll(previousBounds: CGRect)

    /// The content bounds are changed, i.e. the size is changed.
    case boundsChange(previousBounds: CGRect)
  }

  /// The animation behavior of the ComposeView's content update.
  public enum AnimationBehavior {

    /// The default animation behavior.
    ///
    /// With this behavior, the content update is animated if:
    /// - the content is refreshed with `animated: true`
    /// - the content is scrolled or resized
    case `default`

    /// The animation is disabled.
    case disabled

    /// The dynamic animation behavior.
    ///
    /// With this behavior, whether the content update is animated is determined by the `shouldAnimate` closure.
    case dynamic(_ shouldAnimate: (_ contentView: ComposeView, _ renderType: RenderType) -> Bool)
  }

  /// The animation behavior of the content update.
  public var animationBehavior: AnimationBehavior = .default

  /// The insets to apply to the visible bounds when determining which content to render.
  ///
  /// - Negative values expand the visible bounds in that direction, causing more content to be rendered.
  /// - Positive values shrink the visible bounds in that direction, causing less content to be rendered.
  ///
  /// The default value is zero for all edges, which means the visible bounds are not adjusted.
  public var visibleBoundsInsets = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

  // MARK: - Private

  /// The block to make content.
  private var makeContent: (ComposeView) -> ComposeContent

  /// The current content node that the view is rendering.
  private var contentNode: LayoutCacheNode?

  /// The context of the current content update.
  private var contentUpdateContext: ContentUpdateContext?

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
    automaticallyAdjustsContentInsets = false

    // set the scroll indicators to be shown by default
    // this is to make the scroll indicators are visible immediately when scrolling for the first time
    showsHorizontalScrollIndicator = true
    showsVerticalScrollIndicator = true

    #if DEBUG
    if Thread.isRunningXCTest {
      // when running tests, the scroller may affect the scroll view's content size.
      scrollIndicatorBehavior = .never
      hasHorizontalScroller = false
      hasVerticalScroller = false
    }
    #endif

    #endif

    #if canImport(UIKit)
    // ensure the content inset is consistent regardless of the safe area
    contentInsetAdjustmentBehavior = .never
    #endif

    observeTheme()
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
    var contentNode = makeContent(self).asVStack()
    _ = contentNode.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: contentScaleFactor))
    return contentNode.size.roundedUp(scaleFactor: contentScaleFactor)
  }

  // MARK: - Scroll

  /// The view's scrollable behavior.
  public enum ScrollBehavior {

    /// The view is scrollable if the content is larger than the view's bounds. Otherwise, the view is not scrollable.
    case auto

    /// The view is always scrollable. The view will always bounce.
    case always

    /// The view is never scrollable.
    case never
  }

  /// The view's scrollable behavior. The default value is `.auto`.
  public var scrollBehavior: ScrollBehavior = .auto {
    didSet {
      switch scrollBehavior {
      case .auto:
        break
      case .always:
        isScrollable = true
        alwaysBounceHorizontal = true
        alwaysBounceVertical = true
      case .never:
        isScrollable = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
      }
    }
  }

  /// The view's scroll indicator behavior.
  public enum ScrollIndicatorBehavior {

    /// The scroll indicators are shown if the content is larger than the view's bounds. Otherwise, the scroll indicators are hidden.
    case auto

    /// The scroll indicators are never shown even if the content is larger than the view's bounds.
    case never
  }

  /// The view's scroll indicator behavior. The default value is `.auto`.
  public var scrollIndicatorBehavior: ScrollIndicatorBehavior = .auto {
    didSet {
      switch scrollIndicatorBehavior {
      case .auto:
        break
      case .never:
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
      }
    }
  }

  // MARK: - Theme

  private var themeObservation: AnyCancellable?

  private func observeTheme() {
    themeObservation = themePublisher.dropFirst().sink { [weak self] _ in
      self?.setNeedsRefresh(animated: true)
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
    contentNode = LayoutCacheNode(node: makeContent(self).asVStack())
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
      // no pending render request but bounds changed, should re-render the content

      if lastRenderBounds == .zero {
        // the content is never made, should make a new content
        contentNode = LayoutCacheNode(node: makeContent(self).asVStack())
      }

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

    // update scrollable behavior
    switch scrollBehavior {
    case .auto:
      isScrollable = contentSize.width > boundsSize.width || contentSize.height > boundsSize.height
      alwaysBounceHorizontal = false
      alwaysBounceVertical = false
    case .always:
      isScrollable = true
      alwaysBounceHorizontal = true
      alwaysBounceVertical = true
    case .never:
      isScrollable = false
      alwaysBounceHorizontal = false
      alwaysBounceVertical = false
    }

    // update scroll indicator behavior
    let oldShowsHorizontalScrollIndicator = showsHorizontalScrollIndicator
    let oldShowsVerticalScrollIndicator = showsVerticalScrollIndicator

    switch scrollIndicatorBehavior {
    case .auto:
      showsHorizontalScrollIndicator = contentSize.width > boundsSize.width
      showsVerticalScrollIndicator = contentSize.height > boundsSize.height
    case .never:
      showsHorizontalScrollIndicator = false
      showsVerticalScrollIndicator = false
    }

    if (oldShowsHorizontalScrollIndicator == false && showsHorizontalScrollIndicator == true) ||
      (oldShowsVerticalScrollIndicator == false && showsVerticalScrollIndicator == true)
    {
      flashScrollIndicators()
    }

    #if canImport(AppKit)
    invalidateScrollElasticity()
    #endif

    // set up the renderable item ids and map
    let oldRenderableItemIds = renderableItemIds
    let oldRenderableItemMap = renderableItemMap
    let oldRenderableMap = renderableMap

    let renderableItemsCount = renderableItems.count
    renderableItemIds = []
    renderableItemIds.reserveCapacity(renderableItemsCount)
    renderableItemMap = [:]
    renderableItemMap.reserveCapacity(renderableItemsCount)
    renderableMap = [:]
    renderableMap.reserveCapacity(renderableItemsCount)

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
          oldRenderableItem.willRemove?(oldRenderable, RenderableRemoveContext(oldFrame: oldFrame, contentView: self))

          let removeBlock = {
            oldRenderable.removeFromParent()
            oldRenderableItem.didRemove?(oldRenderable, RenderableRemoveContext(oldFrame: oldFrame, contentView: self))
          }

          if context.shouldAnimate(contentView: self, animationBehavior: animationBehavior), let transition = oldRenderableItem.transition?.remove {
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

        renderable.layer.reset()

        let updateType: RenderableUpdateType
        switch context.updateType {
        case .refresh:
          updateType = .refresh
        case .boundsChange(let previousBounds):
          if previousBounds.size == bounds.size {
            updateType = .scroll
          } else {
            updateType = .boundsChange
          }
        }

        let oldFrame = renderable.frame
        let newFrame = renderableItem.frame.rounded(scaleFactor: contentScaleFactor)

        let animationTiming: AnimationTiming?
        if context.shouldAnimate(contentView: self, animationBehavior: animationBehavior), let renderableItemAnimationTiming = renderableItem.animationTiming {
          animationTiming = renderableItemAnimationTiming
        } else {
          animationTiming = nil
        }

        let renderableUpdateContext = RenderableUpdateContext(
          updateType: updateType,
          oldFrame: oldFrame,
          newFrame: newFrame,
          animationTiming: animationTiming,
          contentView: self
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
        } else {
          renderable = CATransaction.disableAnimations { // no animation context for making new renderables
            renderableItem.make(RenderableMakeContext(initialFrame: newFrame, contentView: self))
          }
        }

        renderable.layer.reset()

        let frameBeforeWillInsert = renderable.frame
        renderableItem.willInsert?(renderable, RenderableInsertContext(oldFrame: frameBeforeWillInsert, newFrame: newFrame, contentView: self))
        let frameAfterWillInsert = renderable.frame

        let renderableUpdateContext = RenderableUpdateContext(
          updateType: .insert,
          oldFrame: frameAfterWillInsert,
          newFrame: newFrame,
          animationTiming: nil, // no animation for insertion
          contentView: self
        )

        renderableItem.willUpdate?(renderable, renderableUpdateContext)

        renderable.addToParent(contentView())

        CATransaction.disableAnimations {
          renderable.setFrame(newFrame) // no animation context for insertion
        }

        renderableItem.update(renderable, renderableUpdateContext)

        let renderableInsertContext = RenderableInsertContext(oldFrame: frameAfterWillInsert, newFrame: newFrame, contentView: self)
        if context.shouldAnimate(contentView: self, animationBehavior: animationBehavior), let transition = renderableItem.transition?.insert {
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

  // MARK: - Testing

  #if DEBUG

  var test: Test { Test(host: self) }

  class Test {

    private let host: ComposeView

    fileprivate init(host: ComposeView) {
      assert(Thread.isRunningXCTest, "Test namespace should only be used in test target.")
      self.host = host
    }

    var removingRenderableMap: [String: Renderable] {
      host.removingRenderableMap
    }

    var removingRenderableTransitionCompletionMap: [String: CancellableBlock] {
      host.removingRenderableTransitionCompletionMap
    }
  }

  #endif
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
