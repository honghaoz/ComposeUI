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
- The insert transition context gains `revivalPosition` and `revivalTransform` for taking-over transitions.
- `ComposeView` now re-renders on display scale changes on iOS/tvOS, matching the existing macOS handling.
- `ComposeView.setNeedsRefresh(animated:)` now merges coalesced requests to non-animated when any request was non-animated.
- A render pass no longer animates the frame of a reused renderable whose frame is unchanged, and it recognizes unchanged frames on 3x displays too, where the frame derived from the layer does not round-trip and used to be re-applied on every pass. `DropShadowLayer` and `InnerShadowLayer` skip their mask's frame animations the same way.
- `DropShadowLayer` and `InnerShadowLayer` now animate only the shadow properties, and the mask path, that changed. An animated update that changes one input, for example the shadow color on a theme change, no longer adds a no-op animation for every other property. Their `update` path closures are no longer `@escaping`, since they are called synchronously.
- A non-animated `DropShadowLayer`, `InnerShadowLayer` or `ColorNode` update now continues in-flight animations toward the new values instead of letting them finish toward the old ones and then snapping. The shadow opacity animates non-additively, since opposing additive opacity animations don't compose on screen.
- Added `CALayer.retarget(keyPath:to:)`, which sets a property and continues its in-flight animations toward the new value.
- Fixed `CALayer.retarget(keyPath:to:)` and `CALayer.animate` crashing or losing the change on macOS when setting a geometry key path such as `position.x` or `bounds` on a view-backed layer.
- Drop and inner shadow paths now animate with the frame, including through interrupted resizes.
- `DropShadowLayer` and `InnerShadowLayer` can now be created and subclassed outside the framework: their initializers are public.
- The render pass now asserts, in debug builds, that a renderable's transform is identity when it applies the frame, so a `willInsert` or `willUpdate` block that sets a transform is reported consistently instead of misrendering or asserting only on animated passes. Set transforms in `update`, where they are reset and re-applied on every pass. See `Renderable`.
- `AnimationTiming` now asserts, in debug builds, on invalid values and falls back: a speed of 0 or less, or NaN, becomes 1. An infinite or NaN delay becomes 0. An infinite or NaN duration becomes `Animations.defaultAnimationDuration`, or the spring descriptor's duration for a spring.

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
