# CHANGELOG

## Unreleased

### Breaking Changes

- With the default animation behavior, bounds changes no longer animate reused renderables' updates (scrolling used to), and now run the configured insert and remove transitions of entering and leaving renderables on resizes and the first layout as well as scrolls. Refreshes still control both with their `animated` flag, and running animations are left to finish.
- Replaced `ComposeView.RenderType.scroll` with `.boundsChange(previousBounds:bounds:)`. A scroll is a bounds change whose size is unchanged: `case .boundsChange(let previousBounds, let bounds) where previousBounds?.size == bounds.size`.
- Shadow paths now follow renderable size instead of viewport size. Request a refresh when other path inputs change.
- Drop and inner shadow path providers now receive the shadow's size instead of the renderable or layer, and `DropShadowLayer.update(...)` and `InnerShadowLayer.update(...)` take `paths` or `path` like the nodes.
- Merged `RenderableUpdateType.scroll` into `.boundsChange`. Compare `RenderableUpdateContext.previousRenderBounds` and `renderBounds` to distinguish scrolling from resizing.
- Removed `RenderableUpdateType.requiresFullUpdate`. Handle update types explicitly according to the renderable's dependencies, including bounds-dependent drawing and scroll effects.
- Resizing `ComposeView` now lays out its existing content without reevaluating the content builder. Request `refresh()` or `setNeedsRefresh()` to apply changed configuration.
- `SwiftUIViewNode` now evaluates dynamic content lazily when measurement or insertion first needs it and reuses that value until refresh.
- `LayoutCacheNode` is no longer available.
- Delayed animations are now scheduled with Core Animation's `beginTime` instead of a GCD timer.
- Zero-duration transitions now call their completion, and a completion is also called when its animation is torn down early.
- `RenderableTransition.opacity`'s `to` is now optional, and without it the fade ends at the opacity the content sets, for example with the `opacity` modifier, instead of 1.
- `ComposeView.tile()` is now final on macOS. The content lays out for the view's bounds whether or not scroll bars show, so tiling that takes space from the clip view would cover the content. Place accessory views outside the `ComposeView` instead.
- Removed `ScrollViewType`. `ScrollView` now has UIKit's scroll view API on macOS too: `contentOffset` replaces `contentOffset()` and `setContentOffset(_:)`, `contentSize` replaces `contentSize()` and `setContentSize(_:)`, `adjustedContentInset` replaces `contentInsets()`, `contentInset` replaces `setContentInsets(_:)`, and `contentOffset` with `visibleSize` replace `bounds()`. On macOS, `setContentOffset(_:)` clamped the offset into the scrollable range, while setting `contentOffset` keeps it as set, as on UIKit. To keep `setBounds(_:)`'s behavior, assign `bounds` on iOS, tvOS and visionOS, which resizes the view around its center, and on macOS set `frame.size`, then `contentOffset`, as it did there except for ignoring the x offset and clamping the y offset into the scrollable range. Setting `frame.size`, then `contentOffset` resizes from the view's origin on every platform. `contentView()` and the macOS `documentView()` are no longer public: on macOS, `contentView()` shared its name with AppKit's `NSScrollView.contentView()`, so a call in an optional or inferred context returned the clip view instead of the document view. Use `documentView` on macOS, and the scroll view itself on iOS, tvOS and visionOS.
- Renamed `BaseScrollView.isScrollable` to UIKit's `isScrollEnabled`, which `ScrollView` now has on macOS too, and the debug event `renderDidUpdateScrollableBehavior(isScrollable:alwaysBounceHorizontal:alwaysBounceVertical:)` to `renderDidUpdateScrollableBehavior(isScrollEnabled:alwaysBounceHorizontal:alwaysBounceVertical:)`.
- On macOS, `ComposeView` no longer supports automatic content insets, magnification or borders, so its content insets stay the same under the title bar and toolbar, and its content always lays out for its bounds. `automaticallyAdjustsContentInsets` and `allowsMagnification` stay `false`, `magnification`, `minMagnification` and `maxMagnification` stay 1, so `setMagnification(_:centeredAt:)` and `magnify(toFit:)` don't magnify either, even through the animator, and `borderType` stays `.noBorder`. Changing them asserts and keeps the current value, and they're final on `ComposeView`.

### Changes

- Added previous and current viewport bounds to `RenderableUpdateContext`.
- Fixed a render pass without an `onWillRender` handler using the scroll offset from before a content-size change, which dropped the items visible at the clamped offset until the next layout.
- `ComposeViewNode` now updates an already-mounted child view's content when the parent is refreshed. The child renders within the parent's render pass. Properties set on the child view in `onInsert` or `onUpdate` no longer apply to its first render. Set them in `willInsert` or `willUpdate` instead.
- A nested `ComposeView`, rendered by `ComposeViewNode` or hosted by a `ViewNode`, lays out within the parent's render pass when that pass inserts or resizes it. A render pass that runs within another view's render pass, for any view inside the rendering view's hierarchy, never runs more transitions or animations than the outer pass allows, whatever the nested view's own `animationBehavior`.
- A render pass requested while another view's render pass is in progress, for example a refresh or a forced layout from a render handler, runs after that pass, under the view's own `animationBehavior`. The exception is a view nested in the rendering view, once that pass has made its animation decision (after `onWillLayout` and `onWillRender`): it renders within the pass, capped by that decision. Before, only a refresh of the rendering view itself was deferred.
- When a render handler or a renderable lifecycle block changes the view's bounds during its own render pass, for example a resize from `onDidRender`, the new bounds now render after the pass. Before, only a size change from `onWillRender` did.
- The `AnimationBehavior.dynamic` closure is now called once per render pass instead of once per renderable, so one decision applies to the whole pass.
- Added a scale transition, `.scale(from:anchor:timing:options:)`.
- Slide transitions now continue a revival from wherever the removal left the renderable.
- A spring opacity transition now continues a revival with the removal's speed, instead of starting from rest.
- The insert transition context gains `revivalPosition` and `revivalTransform` for taking-over transitions.
- Added `InsertTransition.prepareForTakeover`, which prepares a revived renderable before its content update. A transition that wraps an insert transition forwards it.
- `ComposeView` now re-renders on display scale changes on iOS/tvOS, matching the existing macOS handling.
- `ComposeView.setNeedsRefresh(animated:)` now merges coalesced requests to non-animated when any request was non-animated.
- A render pass no longer animates the frame of a reused renderable whose frame is unchanged, and it recognizes unchanged frames on 3x displays too, where the frame derived from the layer does not round-trip and used to be re-applied on every pass. `DropShadowLayer` and `InnerShadowLayer` skip their mask's frame animations the same way.
- `DropShadowLayer` and `InnerShadowLayer` now animate only the shadow properties, and the mask path, that changed. An animated update that changes one input, for example the shadow color on a theme change, no longer adds a no-op animation for every other property. Their `update` path closures are no longer `@escaping`, since they are called synchronously.
- A non-animated `DropShadowLayer`, `InnerShadowLayer`, `ColorNode` or node modifier update now continues in-flight animations toward the new values instead of letting them finish toward the old ones and then snapping. The shadow opacity animates non-additively, since opposing additive opacity animations don't compose on screen.
- Node modifiers and `ColorNode` now animate only the properties that changed.
- Stacked modifiers of one property, such as `.opacity(0.3).opacity(1)`, now apply only the outermost one, so an animated refresh no longer animates through the inner values.
- The `opacity` and `shadow` modifiers now animate an opacity from the shown value instead of stacking additive animations, so reversing a change in flight no longer jumps, and a non-animated change continues an in-flight animation.
- Added `CALayer.retarget(keyPath:to:)`, which sets a property and continues its in-flight animations toward the new value.
- Fixed `CALayer.retarget(keyPath:to:)` and `CALayer.animate` crashing, losing the change, or dropping the layer's transform on macOS when setting a geometry key path such as `position.x` or `bounds` on a view-backed layer.
- Drop and inner shadow paths now animate with the frame, including through interrupted resizes.
- `DropShadowLayer` and `InnerShadowLayer` can now be created and subclassed outside the framework: their initializers are public.
- The render pass now asserts, in debug builds, that a renderable's transform is identity when it applies the frame, so a `willInsert` or `willUpdate` block that sets a transform is reported consistently instead of misrendering or asserting only on animated passes. Set transforms in `update`, where they are reset and re-applied on every pass. See `Renderable`.
- `AnimationTiming` now asserts, in debug builds, on invalid values and falls back: a speed of 0 or less, or NaN, becomes 1. An infinite or NaN delay becomes 0. An infinite or NaN duration becomes `Animations.defaultAnimationDuration`, or the spring descriptor's duration for a spring.
- Animations that ComposeUI adds now begin at a time read once per turn of the main run loop, instead of when Core Animation commits the transaction. Later updates evaluate them from the time they begin on screen, so a shadow's paths stay on its frame through interrupted resizes, even when a busy main thread delays the commit, and a non-animated update continues an animation from where it shows. The first frame of an animation shows it as far in as the time from the turn's first animation to that frame. The time holds until the main run loop turns, which XCTest doesn't do between test methods, so a test that compares animations with the media time should turn the run loop first.

## [0.0.5](https://github.com/honghaoz/ComposeUI/releases/tag/0.0.5) (2026-08-08)

### Breaking Changes

- `ViewNode` and `LayerNode` intrinsic size closures now receive only the proposed `CGSize`. Capture an external view or layer when its instance is needed for measurement.
- `ScrollViewType` now requires custom conformers to implement `clipsToBounds`.
- `ComposeView` behavior enums gained new cases, and render debug events now use `ComposeNodeId` and updated event names. Update exhaustive switches and debug handlers as needed.
- `RenderableTransition` contexts now expose `ComposeView`, and `CALayer.animate` value closures now receive the concrete layer type through `Self`.

### Changes

- Added `map(_:)` transforms to `ComposeNode`.
- Added layout and render lifecycle callbacks to `ComposeView`.
- Added renderable reuse APIs and a shared renderable pool.
- Added `zIndex(_:)` support and fixed view/layer ordering on AppKit.
- Added manual scroll, scroll indicator, and clipping behaviors.
- Improved rendering performance with stack culling, render item caching, pooled renderables, and text sizing caches.
- Improved SwiftUI sizing and safe area handling.
- Fixed transition cancellation and state restoration when renderables are removed or revived.
- Fixed text interaction, shadow clipping, and inner shadow fallback rendering.
- Other various improvements and bug fixes.

## [0.0.4](https://github.com/honghaoz/ComposeUI/releases/tag/0.0.4) (2026-01-04)

- Optimized text support.
- Optimized SwiftUI support.
- Added `clippingBehavior` to `ComposeView`.
- Added `ifLet` support for `ComposeNode`.
- Added `ComposeViewNode` to render nested compose content.
- Updated inner shadow layer/node to support "spread" effect.
- Added key equivalent support for button view/node.
- Exposed various CA layer animation APIs.
- Other various improvements and bug fixes.

## [0.0.3](https://github.com/honghaoz/ComposeUI/releases/tag/0.0.3) (2025-04-12)

- Added animation support
- Added drop shadow, inner shadow support
- Added `TextAreaNode`
- Added more theming support
- `ComposeView` now automatically refreshes on key window change
- Improved scroll behavior
- Improved layout performance
- Fixed various text view bugs

## [0.0.2](https://github.com/honghaoz/ComposeUI/releases/tag/0.0.2) (2025-03-23)

- Added theming support
- Added SwiftUI view support (`SwiftUIViewNode`)
- Added gesture recognizers support
- Added `Text` (`LabelNode`) support for AppKit
- Added `mapChildren` support for container nodes
- Added `width(_:, alignment:)`, `height(_:, alignment:)` and `alignment(_:)`
- Improved nested scroll views scrolling behavior for AppKit
- Improved performance by avoiding excessive renderable updates

## [0.0.1](https://github.com/honghaoz/ComposeUI/releases/tag/0.0.1) (2025-03-18)

- Initial release 🎉
