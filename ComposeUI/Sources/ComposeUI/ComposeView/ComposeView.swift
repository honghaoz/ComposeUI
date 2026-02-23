//
//  ComposeView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit
import Combine

/// A view that renders `ComposeContent`.
open class ComposeView: UIScrollView {

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
        EmptyNode()
    }

    // MARK: - Animation Behavior

    /// The type of the render pass.
    public enum RenderType: Equatable {

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
        /// - the content is scrolled
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
    public var visibleBoundsInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    // MARK: - Private

    /// The block to make content.
    private var makeContent: (ComposeView) throws -> ComposeContent

    /// The current content node that the view is rendering.
    private var contentNode: LayoutCacheNode?

    /// The context of the current content update.
    private var contentUpdateContext: ContentUpdateContext?

    /// The bounds used for last render pass.
    private var lastRenderBounds: CGRect = .zero

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
    public init(@ComposeContentBuilder content: @escaping (ComposeView) throws -> ComposeContent) {
        self.makeContent = content

        super.init(frame: .zero)

        commonInit()
    }

    /// Creates a `ComposeView` with the given content.
    ///
    /// - Parameter content: The content builder block.
    public init(@ComposeContentBuilder content: @escaping () throws -> ComposeContent) {
        makeContent = { _ in try content() }

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
        makeContent = { _ in EmptyNode() }

        super.init(frame: frame)

        makeContent = { [unowned self] _ in content } // swiftlint:disable:this unowned_variable_capture
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
    }

    private func commonInit() {
        contentScaleFactor = windowScaleFactor

        // ensure the content inset is consistent regardless of the safe area
        contentInsetAdjustmentBehavior = .never
    }

    // MARK: - Content

    /// Set a new content.
    ///
    /// An animated refresh will be scheduled. To disable the animation, call `setNeedsRefresh(animated: false)` or `refresh(animated: false)`.
    ///
    /// - Parameter content: The content builder block. It passes in the content view that renders the content.
    open func setContent(@ComposeContentBuilder content: @escaping (ComposeView) throws -> ComposeContent) {
        makeContent = content
        setNeedsRefresh()
    }

    /// Set a new content.
    ///
    /// An animated refresh will be scheduled. To disable the animation, call `setNeedsRefresh(animated: false)` or `refresh(animated: false)`.
    ///
    /// - Parameter content: The content builder block.
    open func setContent(@ComposeContentBuilder content: @escaping () throws -> ComposeContent) {
        setContent(content: { _ in try content() })
    }

    /// Makes the content node.
    private func _makeContent() -> ComposeNode {
        do {
            return try makeContent(self).asVStack()
        } catch {
            print("[ComposeUI] Failed to make content: \(error)")
            assertionFailure("Failed to make content: \(error)")
            return EmptyNode()
        }
    }

    // MARK: - Render Callbacks

    /// The context for the pre-render handler.
    public struct PreRenderContext {

        /// The content size after layout.
        ///
        /// If the content is smaller than the bounds in either dimension, the content size is adjusted to be the same as the bounds.
        public let contentSize: CGSize

        /// The bounds that is used for layout and will be used for rendering if no change is detected in the pre-render handler.
        ///
        /// The bounds's size is the layout container size.
        public let renderBounds: CGRect

        /// The render type for this pass.
        public let renderType: RenderType
    }

    private var preRenderHandler: ((_ view: ComposeView, _ context: PreRenderContext) -> Void)?

    /// Set a handler to be called after layout computed the content size and updated the scroll view's content size,
    /// but before renderable items are requested.
    ///
    /// This handler gives you a chance to adjust the content offset so it affects the visible bounds for rendering.
    ///
    /// For example, for chat-like UI, you can use this handler to adjust the content offset to be at the bottom, so the renderable items are rendered from the bottom.
    ///
    /// Calling this replaces any previously set handler.
    ///
    /// - Parameter handler: The pre-render handler.
    /// - Returns: The ComposeView itself.
    @discardableResult
    public func onPreRender(_ handler: @escaping (_ view: ComposeView, _ context: PreRenderContext) -> Void) -> Self {
        preRenderHandler = handler
        return self
    }

    // MARK: - Debug

    #if DEBUG
    private var debug: Debug?

    /// Set a debug handler to the ComposeView.
    ///
    /// - Parameter eventHandler: The event handler to handle the debug events.
    /// - Returns: The ComposeView itself.
    @discardableResult
    public func debug(eventHandler: @escaping (_ view: ComposeView, _ event: ComposeView.Debug.Event) -> Void) -> Self {
        debug = Debug(composeView: self, eventHandler: eventHandler)
        return self
    }
    #endif

    // MARK: - Size

    /// Get the size that fits the content.
    ///
    /// - Parameter size: The container size.
    /// - Returns: The size that fits the content.
    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        var contentNode = _makeContent()
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
                isScrollEnabled = true
                alwaysBounceHorizontal = true
                alwaysBounceVertical = true
            case .never:
                isScrollEnabled = false
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

    // MARK: - Clipping

    /// The view's clipping behavior.
    public enum ClippingBehavior {

        /// The view clips the content to the bounds when the view is scrollable.
        case auto

        /// The view always clips the content to the bounds.
        case always

        /// The view never clips the content.
        case never
    }

    /// The view's clipping behavior. The default value is `.auto`.
    public var clippingBehavior: ClippingBehavior = .auto

    // MARK: - Window

    private weak var previousWindow: UIWindow?

    override open func didMoveToWindow() {
        super.didMoveToWindow()

        contentScaleFactor = windowScaleFactor

        if window != nil, previousWindow != window {
            setNeedsRefresh(animated: false) // schedule to refresh when the window is changed
        }
        previousWindow = window
    }

    // MARK: - Render

    /// Refreshes and re-renders the content.
    ///
    /// This call will make a new content from the builder block and re-render the content immediately.
    ///
    /// - Parameter animated: Whether the refresh is animated. Default value is `true`.
    open func refresh(animated: Bool = true) {
        assert(Thread.isMainThread, "refresh(animated:) must be called on the main thread")

        // explicit render request, should make a new content
        contentNode = LayoutCacheNode(node: _makeContent())
        contentUpdateContext = ContentUpdateContext(updateType: .refresh(isAnimated: animated), renderBounds: renderBounds())

        // cancel the pending refresh if there is any to avoid double rendering
        // this can happen if `setNeedsRefresh(animated:)` is called then `refresh(animated:)` is called immediately
        if pendingRefresh != nil {
            pendingRefresh = nil
        }

        render()
    }

    private struct PendingRefresh {
        let isAnimated: Bool
    }

    private var pendingRefresh: PendingRefresh?

    /// Requests a refresh of the content.
    ///
    /// This method is non-blocking and will return immediately.
    /// The refresh will be performed on the next run loop iteration.
    ///
    /// - Parameter animated: Whether the refresh is animated. Default value is `true`.
    open func setNeedsRefresh(animated: Bool = true) {
        assert(Thread.isMainThread, "setNeedsRefresh(animated:) must be called on the main thread")

        if pendingRefresh == nil {
            RunLoop.main.perform(inModes: [.common]) { [weak self] in
                self?.performPendingRefresh()
            }
        }

        pendingRefresh = PendingRefresh(isAnimated: animated)
    }

    private func performPendingRefresh() {
        guard let pendingRefresh else {
            return
        }

        self.pendingRefresh = nil
        refresh(animated: pendingRefresh.isAnimated)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        guard pendingRefresh == nil else {
            // pending refreshes could be scheduled from window change, for the layout call, just perform the pending refresh
            performPendingRefresh()
            return
        }

        let renderBounds = renderBounds()
        if contentUpdateContext == nil, renderBounds != lastRenderBounds {
            // no pending render request but bounds changed, should re-render the content

            if contentNode == nil || renderBounds.size != lastRenderBounds.size {
                // the content is never made or bounds size changed, should make a new content
                contentNode = LayoutCacheNode(node: _makeContent())
            }

            contentUpdateContext = ContentUpdateContext(updateType: .boundsChange(previousRenderBounds: lastRenderBounds), renderBounds: renderBounds)
        }

        render()
    }

    /// Performs a render pass.
    open func render() {
        assert(Thread.isMainThread, "render() must be called on the main thread")

        guard var contentUpdateContext = self.contentUpdateContext, !contentUpdateContext.isRendering else {
            return
        }

        contentUpdateContext.isRendering = true
        self.contentUpdateContext = contentUpdateContext

        CATransaction.disableAnimations { // disable all implicit animations to have a clean environment for rendering
            render(contentUpdateContext)
        }

        self.contentUpdateContext = nil
    }

    private func render(_ context: ContentUpdateContext) {
        guard let contentNode else {
            return
        }

        #if DEBUG
        debug?.onEvent(.renderWillBegin(contentNode: contentNode))
        #endif

        var bounds = context.renderBounds
        let boundsSize = bounds.size

        #if DEBUG
        let layoutVisibleBounds = bounds.inset(by: visibleBoundsInsets)
        debug?.onEvent(.renderWillLayout(contentNode: contentNode, bounds: bounds, visibleBounds: layoutVisibleBounds))
        #endif

        // do the layout
        _ = contentNode.layout(containerSize: boundsSize, context: ComposeNodeLayoutContext(scaleFactor: contentScaleFactor))
        var contentSize = contentNode.size

        #if DEBUG
        debug?.onEvent(.renderDidLayout(contentSize: contentSize))
        #endif

        var centeredChildFrame: CGRect?
        if contentSize.width < boundsSize.width || contentSize.height < boundsSize.height {
            // if content is smaller than the bounds in either dimension, should center the content

            let adjustedContentSize = CGSize(
                width: max(contentSize.width, boundsSize.width),
                height: max(contentSize.height, boundsSize.height)
            )

            // logic copied from FrameNode.renderableItems(in:) (part 1)
            centeredChildFrame = ComposeLayout.position(rect: contentSize, in: adjustedContentSize, alignment: .center)
            contentSize = adjustedContentSize
        }

        let roundedContentSize = contentSize.roundedUp(scaleFactor: contentScaleFactor)

        // set content size
        contentSize = roundedContentSize

        // call the pre-render handler if there is any
        // this gives the caller a chance to adjust the content offset before the renderable items are requested
        let hasPreRenderHandler = preRenderHandler != nil
        if let preRenderHandler {
            let renderType: RenderType
            switch context.updateType {
            case .refresh(let isAnimated):
                renderType = .refresh(isAnimated: isAnimated)
            case .boundsChange(let previousRenderBounds):
                if previousRenderBounds.size == boundsSize {
                    renderType = .scroll(previousBounds: previousRenderBounds)
                } else {
                    renderType = .boundsChange(previousBounds: previousRenderBounds)
                }
            }
            preRenderHandler(self, PreRenderContext(contentSize: roundedContentSize, renderBounds: bounds, renderType: renderType))
        }

        if hasPreRenderHandler {
            // the pre-render handler may change the bounds, so we need to adjust the bounds accordingly
            let updatedBounds = renderBounds()

            // only pick up the origin from the updated bounds so that the content offset is updated correctly
            // ignore the size from the updated bounds because the above layout step has already used the old size
            bounds.origin = updatedBounds.origin

            // if the bounds size changed, schedule a follow-up refresh to make sure the new bounds size is used for rendering
            if updatedBounds.size != bounds.size {
                onNextRunLoop { [weak self] in
                    self?.layoutIfNeeded()
                }
            }
        }
        let visibleBounds = bounds.inset(by: visibleBoundsInsets)

        // get renderable items
        let renderableItems: [RenderableItem]
        if let centeredChildFrame {
            // logic copied from FrameNode.renderableItems(in:) (part 2)
            let boundsInChild = visibleBounds.translate(-centeredChildFrame.origin)

            #if DEBUG
            debug?.onEvent(.renderWillRequestRenderableItems(visibleBounds: boundsInChild))
            #endif

            let childItems = contentNode.renderableItems(in: boundsInChild)

            var mappedChildItems: [RenderableItem] = []
            mappedChildItems.reserveCapacity(childItems.count)

            for var item in childItems {
                item.frame = item.frame.translate(centeredChildFrame.origin)
                mappedChildItems.append(item)
            }

            renderableItems = mappedChildItems
        } else {
            #if DEBUG
            debug?.onEvent(.renderWillRequestRenderableItems(visibleBounds: visibleBounds))
            #endif

            renderableItems = contentNode.renderableItems(in: visibleBounds)
        }

        #if DEBUG
        debug?.onEvent(.renderDidReceiveRenderableItems(renderableItems: renderableItems, contentSize: contentSize))
        #endif

        // update scrollable behavior
        switch scrollBehavior {
        case .auto:
            isScrollEnabled = contentSize.width > boundsSize.width || contentSize.height > boundsSize.height
            alwaysBounceHorizontal = false
            alwaysBounceVertical = false
        case .always:
            isScrollEnabled = true
            alwaysBounceHorizontal = true
            alwaysBounceVertical = true
        case .never:
            isScrollEnabled = false
            alwaysBounceHorizontal = false
            alwaysBounceVertical = false
        }

        #if DEBUG
        debug?.onEvent(.renderDidUpdateScrollableBehavior(isScrollable: isScrollEnabled, alwaysBounceHorizontal: alwaysBounceHorizontal, alwaysBounceVertical: alwaysBounceVertical))
        #endif

        switch clippingBehavior {
        case .auto:
            clipsToBounds = isScrollEnabled
        case .always:
            clipsToBounds = true
        case .never:
            clipsToBounds = false
        }

        #if DEBUG
        debug?.onEvent(.renderDidUpdateClippingBehavior(clipsToBounds: clipsToBounds))
        #endif

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

        #if DEBUG
        debug?.onEvent(.renderDidUpdateScrollIndicatorBehavior(showsHorizontalScrollIndicator: showsHorizontalScrollIndicator, showsVerticalScrollIndicator: showsVerticalScrollIndicator))
        #endif

        // set up the renderable item ids and map
        let oldRenderableItemIds = renderableItemIds
        let oldRenderableItemMap = renderableItemMap
        let oldRenderableMap = renderableMap

        #if DEBUG
        // sanity check for old renderable item ids and maps before rendering
        assert(oldRenderableItemIds.count == oldRenderableItemMap.count, "mismatched old renderable item count")
        assert(oldRenderableItemIds.count == oldRenderableMap.count, "mismatched old renderable count")
        for id in oldRenderableItemIds {
            assert(oldRenderableItemMap[id] != nil, "missing old renderable item: \(id)")
            assert(oldRenderableMap[id] != nil, "missing old renderable: \(id)")
        }
        #endif

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
                        // if there's a remove transition, it can take time to complete, we need to track the old renderable until the
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

                            #if DEBUG
                            debug?.onEvent(.renderDidRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
                            #endif

                        } cancel: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.removingRenderableMap.removeValue(forKey: oldId)
                            self.removingRenderableTransitionCompletionMap.removeValue(forKey: oldId)

                            #if DEBUG
                            debug?.onEvent(.renderDidCancelRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
                            #endif
                        }

                        removingRenderableTransitionCompletionMap[oldId] = completion

                        #if DEBUG
                        debug?.onEvent(.renderWillRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
                        #endif

                        transition.animate(
                            renderable: oldRenderable,
                            context: RenderableTransition.RemoveTransition.Context(contentView: self),
                            completion: completion.execute
                        )
                    } else {
                        #if DEBUG
                        debug?.onEvent(.renderWillRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
                        #endif

                        removeBlock()

                        #if DEBUG
                        debug?.onEvent(.renderDidRemoveRenderable(item: oldRenderableItem, renderable: oldRenderable))
                        #endif
                    }
                } else {
                    assertionFailure("old renderable item or old renderable not found: \(oldId)")
                }
            } else {
                // this renderable item is still in the content, plan to reuse it
                reusingIds.insert(oldId)
            }
        }

        // determine if z-order needs updating.
        //
        // If no items were removed and no new items are inserted, the existing subview order is already correct and
        // `moveToFront()` calls can be skipped entirely. Each `moveToFront()` triggers `bringSubviewToFront` → `CA::Layer::set_sublayers`
        // → `update_sublayers` → `qsort`, which is O(N log N) per call. With N views that compounds to O(N² log N).
        // This flag avoids all of it in the common case, i.e. scrolling, same content.
        let needsZOrderUpdate: Bool = renderableItemIds != oldRenderableItemIds

        for id in renderableItemIds {
            let renderableItem = renderableItemMap[id]! // swiftlint:disable:this force_unwrapping

            let renderable: Renderable
            if reusingIds.contains(id) {
                // [2/3] ♻️ reuse the renderable item that is still in the content
                renderable = oldRenderableMap[id]! // swiftlint:disable:this force_unwrapping

                #if DEBUG
                debug?.onEvent(.renderWillReuseRenderable(item: renderableItem, renderable: renderable))
                #endif

                renderable.layer.reset()

                let updateType: RenderableUpdateType
                switch context.updateType {
                case .refresh:
                    updateType = .refresh
                case .boundsChange(let previousRenderBounds):
                    if previousRenderBounds.size == bounds.size {
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

                if needsZOrderUpdate {
                    renderable.moveToFront()
                }

                if let animationTiming {
                    renderable.layer.animateFrame(to: newFrame, timing: animationTiming)
                } else {
                    renderable.setFrame(newFrame)
                }

                renderableItem.update(renderable, renderableUpdateContext)

                #if DEBUG
                debug?.onEvent(.renderDidReuseRenderable(item: renderableItem, renderable: renderable))
                #endif

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
                    renderable = renderableItem.make(RenderableMakeContext(initialFrame: newFrame, contentView: self))
                }

                #if DEBUG
                debug?.onEvent(.renderWillInsertRenderable(item: renderableItem, renderable: renderable))
                #endif

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

                renderable.addToParent(self)
                renderable.setFrame(newFrame)

                renderableItem.update(renderable, renderableUpdateContext)

                let renderableInsertContext = RenderableInsertContext(oldFrame: frameAfterWillInsert, newFrame: newFrame, contentView: self)
                if context.shouldAnimate(contentView: self, animationBehavior: animationBehavior), let transition = renderableItem.transition?.insert {
                    // has insert transition, animate the renderable insertion
                    transition.animate(
                        renderable: renderable,
                        context: RenderableTransition.InsertTransition.Context(targetFrame: newFrame, contentView: self),
                        completion: { [weak self] in
                            assert(Thread.isMainThread, "insert transition completion must be called on the main thread")
                            // at the moment, the renderable's frame may not be the target frame, this is because during the insert transition,
                            // the renderable can be refreshed, and the renderable's frame may be updated to a different frame.
                            //
                            // insert: [-------------------] setting frame to frame1
                            // reuse:        [-----]         during the insert transition, the renderable's frame is updated to frame2
                            renderableItem.didInsert?(renderable, renderableInsertContext)

                            #if DEBUG
                            self?.debug?.onEvent(.renderDidInsertRenderable(item: renderableItem, renderable: renderable))
                            #endif
                        }
                    )
                } else {
                    // no insert transition, just call did insert
                    renderableItem.didInsert?(renderable, renderableInsertContext)

                    #if DEBUG
                    debug?.onEvent(.renderDidInsertRenderable(item: renderableItem, renderable: renderable))
                    #endif
                }
            }

            renderableMap[id] = renderable
        }

        #if DEBUG
        // sanity check for renderable item ids and maps after rendering
        assert(renderableItemIds.count == renderableItemMap.count, "mismatched renderable item count")
        assert(renderableItemIds.count == renderableMap.count, "mismatched renderable count")
        for id in renderableItemIds {
            assert(renderableItemMap[id] != nil, "missing renderable item: \(id)")
            assert(renderableMap[id] != nil, "missing renderable: \(id)")
        }
        #endif

        #if DEBUG
        debug?.onEvent(.renderDidFinish(renderableItemIds: renderableItemIds, renderableItemMap: renderableItemMap, renderableMap: renderableMap))
        #endif

        lastRenderBounds = bounds
    }

    /// Returns the bounds used for layout/rendering.
    private func renderBounds() -> CGRect {
        return bounds
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
