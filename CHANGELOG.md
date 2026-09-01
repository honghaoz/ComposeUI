# CHANGELOG

## Unreleased

### Breaking Changes

- Delayed animations are now scheduled with Core Animation's `beginTime` instead of a GCD timer. The animation is added 
  and the model value is set at dispatch, the layer's rendered output holds the pre-animation state for the delay window. 
  An interrupted in-flight opacity transition freezes at its sampled value for a delayed retargeting's delay window 
  instead of continuing to play, and a delayed spring retargeting launches from rest.
- Zero-duration transitions now call their completion. Without a delay, the end state applies and the completion runs 
  immediately. With a delay, the change is scheduled as a snap that applies right after the delay window. A transition 
  completion is also called when its animation is torn down before finishing (superseded, reset, or the layer leaving 
  the layer tree).

### Changes

- Slide transitions now continue a revival from wherever the removal left the renderable, for any side configuration: 
  the `from` side applies only to fresh insertions, and a renderable that fully slid out re-enters from its exit side. 
  The insert transition context gains `revivalPosition`, the model position captured for taking-over transitions.
- `ComposeView` now adopts display scale changes on iOS/tvOS (for example, when the window moves to a screen with a 
  different scale) and re-renders, matching the existing macOS backing scale handling.
- `ComposeView.setNeedsRefresh(animated:)` now merges coalesced requests to non-animated when any request was 
  non-animated (previously the last request's flag won), so a scale-driven or window-driven snap is never animated by a 
  concurrent theme change.

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
