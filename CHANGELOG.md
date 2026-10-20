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
- On macOS, while legacy scroll bars show, `ComposeView` lays out its content for its size minus the space the scroll bars take, so they no longer cover the content. Render handlers and renderable updates receive this smaller area as their render bounds, matching `visibleSize`. `onWillLayout` can now run more than once in a render pass, because the content lays out again when a scroll bar takes space. `tile()` is now final on `ComposeView`, because it sets the visible size that the content lays out for.
- Removed `ScrollViewType`. `ScrollView` now has UIKit's scroll view API on macOS too: `contentOffset` replaces `contentOffset()` and `setContentOffset(_:)`, `contentSize` replaces `contentSize()` and `setContentSize(_:)`, `adjustedContentInset` replaces `contentInsets()`, `contentInset` replaces `setContentInsets(_:)`, and `contentOffset` with `visibleSize` replace `bounds()`. On macOS, `setContentOffset(_:)` clamped the offset into the scrollable range, while setting `contentOffset` keeps it as set, rounded to the nearest pixel, as on UIKit. To keep `setBounds(_:)`'s behavior, assign `bounds` on iOS, tvOS and visionOS, which resizes the view around its center, and on macOS set `frame.size`, then `contentOffset`, as it did there except for ignoring the x offset and clamping the y offset into the scrollable range. Setting `frame.size`, then `contentOffset` resizes from the view's origin on every platform. `contentView()` and the macOS `documentView()` are no longer public: on macOS, `contentView()` shared its name with AppKit's `NSScrollView.contentView()`, so a call in an optional or inferred context returned the clip view instead of the document view. Use `documentView` on macOS, and the scroll view itself on iOS, tvOS and visionOS.
- Renamed `BaseScrollView.isScrollable` to UIKit's `isScrollEnabled`, which `ScrollView` now has on macOS too, and the debug event `renderDidUpdateScrollableBehavior(isScrollable:alwaysBounceHorizontal:alwaysBounceVertical:)` to `renderDidUpdateScrollableBehavior(isScrollEnabled:alwaysBounceHorizontal:alwaysBounceVertical:)`.
- On macOS, `ComposeView` no longer supports automatic content insets, magnification, borders, rulers, the find bar or auto-hiding scroll bars, so its content insets stay the same under the title bar and toolbar. `automaticallyAdjustsContentInsets`, `allowsMagnification`, `rulersVisible`, `isFindBarVisible` and `autohidesScrollers` stay `false`, `magnification`, `minMagnification` and `maxMagnification` stay 1, so `setMagnification(_:centeredAt:)` and `magnify(toFit:)` don't magnify either, even through the animator, and `borderType` stays `.noBorder`. Changing them asserts and keeps the current value, and they're final on `ComposeView`.
- `ComposeView` now lays out, centers and scrolls its content between its content insets (`adjustedContentInset`) instead of ignoring them: `WillLayoutContext.containerSize` is the visible size minus the insets, content that fits between them centers there without scrolling, and `sizeThatFits(_:)` includes them.
- A `VStack` or `HStack` laid out again at the same container size with the same `ComposeNodeLayoutContext` now returns its earlier layout instead of laying out its children again. Create a new context to lay out content again after it changes, as `ComposeView` does for each render pass.
- Creating a `ComposeNodeLayoutContext` off the main thread now asserts in debug builds. Create and use a context on the main thread, where layout runs.
- On macOS, `BaseTextView` now leaves its text in place when it's set to an equal text, as `UITextView` does on iOS and visionOS, so refreshing unchanged text no longer clears its selection, and is faster. To change an attribute object, such as an attachment's image, set a text with a new object instead of changing the object.
- `ComposeContent`'s `asNodes()` is renamed to `_nodes()`, which is framework plumbing: read a content's nodes with the new `nodes` property instead. A type that implemented `asNodes()` to be content becomes a node, or a property or function marked `@ComposeContentBuilder`. A `@ComposeContentBuilder` block places a node as itself, without calling `_nodes()`.
- `ComposeContentBuilder.Item` is now opaque: its cases are internal, since only the builder's methods make items and pass them to each other.
- `ComposeNode` requires `render(visibleBounds:into:)` instead of `renderableItems(in:)`: a node appends its renderable items to the render pass's array in place, instead of returning an array of its own, so scrolling rows of labels allocates 11% to 14% less. `renderableItems(in:)` still returns a node's items, as a method that isn't a requirement. To migrate a node, rename its implementation and append its items instead of returning them. A node with child nodes has them append their items to the same array, and adjusts the items they appended, such as their frames. Delete the old `renderableItems(in:)` implementation, since calls on the node's own type would still use it.
- `ComposeView.theme` stays the same during a render pass, as the theme that the pass read first. Setting `overrideTheme` during the view's render pass, such as from a renderable's update, asserts and keeps the current theme, and it's final on `ComposeView`. Change the theme outside a render pass.
- A text node's text that's neither editable nor selectable, such as a label's by default, now shows in a `TextLabelView` instead of a `BaseTextView`. The label view draws the text with TextKit 1, in the same pixels as the text view, without a text view's machinery for editing, selection and scrolling, so scrolling rows of labels takes 29% to 30% fewer instructions on macOS, 51% to 62% on iOS and 17% to 36% on tvOS, counting the drawing. Code that casts a label's view, such as in `onInsert` or `onUpdate`, gets a `TextLabelView`, which exposes the text and its settings, and assistive technologies read the label as static text, as they read a native label. To keep a text view, make the text selectable.
- A render pass now reuses a view that it removes for a new node of the same kind in place, when the framework sets the view's reuse identifier, as it does for the label and text views of `TextNode` and `LabelNode`, instead of removing the view from the view hierarchy and adding it back from the reuse pool. The superview and window callbacks of the view and its subviews don't run, and on macOS, the view doesn't display again, so scrolling rows of labels and text takes 14% to 46% fewer instructions on macOS, 3% to 8% on iOS and 3% to 9% on tvOS. The view is still in the compose view when the removed node's `onRemove` and `onResetForReuse` blocks run, and is removed at the end of the pass if no new node takes it. A view still gives up the first responder in it, and a view with a touch in progress or the focus, or on macOS any view while a mouse button is pressed, is removed as before, which ends the interaction. A view whose reuse identifier the app sets with `reuseId(_:inPlace:)` goes through the pool as before, unless the app passes `inPlace: true` for a view that doesn't rely on being removed between nodes. A custom `RenderablePoolType` doesn't see the views reused in place.

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
- A render pass no longer animates the frame of a reused renderable whose frame is unchanged, and it recognizes unchanged frames on 3x displays too, where the frame derived from the layer does not round-trip and used to be re-applied on every pass.
- A non-animated frame change of a renderable whose frame is animating now continues the motion instead of jumping: a changed axis of the origin or the size that is moving glides from where it shows to the new frame, landing when its animation would have, a changed axis at rest takes its new value at once, and an axis that didn't change keeps its animation. Drop and inner shadow paths glide with the frame, and their masks stay on the layer without frame animations.
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
- On macOS, scrolling left or right, for example with a mouse's tilt wheel, no longer shifts content that fits the view's width by a pixel. The same goes for scrolling up or down when the content fits the height.
- On macOS, a trackpad or Magic Mouse scroll now stays with the scroll view it started on until its glide ends, as on iOS and in AppKit's own scroll views: a nested scroll view that the scrolling brings under the pointer no longer takes it over, and a gesture that starts during the glide continues it.
- On macOS, a mouse wheel now scrolls the innermost scroll view under the pointer that can scroll in its direction, as a trackpad gesture does, instead of the scroll view that the latest trackpad gesture went to.
- Nested stacks of the same direction with flexible children no longer double the layouts of the nodes in them at each level: a leaf in 8 nested `VStack`s that each hold a spacer now lays out 8 times instead of 128.
- `VStack`, `HStack` and `ZStack` lay out faster.
- On macOS, refreshing and scrolling text is faster: `BaseTextView` fits its text container when its size or inset changes, instead of laying itself out after each change of its text, number of lines or line break mode, and `TextNode` sets only the text view settings that changed.
- Building content with `@ComposeContentBuilder` is faster.
- Refreshing labels is faster: a label reuses the attributed string made for the same text and text settings in an earlier refresh.
- Refreshing a text node whose attributed string is the same object as in the last refresh, as a label's is, is faster: its text view reuses the text with the theme applied instead of applying the theme to a new copy.
- Laying out text is faster: a text's measured size is looked up without allocating.
- Refreshing themed content is faster on macOS: the renderables' updates read the view's appearance once per render pass.
- Starting and retargeting layer animations is faster: the framework passes the key paths it animates to Core Animation without copying them, doesn't store an animation's default speed, and a retarget reads the layer's animations once and keeps them without allocating.
- Refreshing and scrolling are faster: frames, padding, offsets, overlays, underlays, gesture recognizers and modifiers change their child's render items in place instead of copying them, and stacks collect their children's items in one array of the exact size, or reuse the array of their only child with items.
- Fixed a `VStack` or `HStack` that could never finish its layout in release builds when a child has an infinite fixed size, such as from `.frame(width: .infinity, height: 50)`. The stack now divides its space as if the child were flexible. An infinite fixed size still asserts in debug builds, so use `.flexible` to fill the space instead.
- Erasing a view or layer item to a `RenderableItem` is faster: the erased item runs the item's blocks through it, instead of copying each block into a new closure.
- Refreshing and scrolling content with modifiers is faster: a modifier applies all its changes to a render item in one copy of the item, instead of one copy for each change.
- Building content with stacked modifiers is faster: a modifier merges with the modifier it wraps without boxing it, and the built-in modifiers reset the properties they set without reset blocks of their own, which stacked modifiers combined into new closures.
- Building content with built-in modifiers, such as `opacity(_:)` or `backgroundColor(_:)`, is faster: a built-in modifier stores its value instead of a closure that captures it.
- Refreshing content is faster: the built-in nodes, such as `ColorNode` and `TextNode`, share one render item cache per content, instead of each allocating its own when it's made, including the nodes that are never shown. The cache serves a compose view's render passes, so a node's `renderableItems(in:)` called outside one builds its items each time. Make a custom node's child nodes once and keep them across layouts: each built-in node made in a layout keeps its render item until the content is refreshed.
- Building a `LayerNode` or `ViewNode` is faster: it keeps its layer or view factory, the default one or one passed in, without allocating.
- Scrolling text is two to five times faster: text views lay out their text with TextKit 1, as ComposeUI measures text, instead of with TextKit 2 on macOS 13, iOS 16, tvOS 16 and later and on visionOS. A TextKit 2 text view laid out every visible text view again on each scroll step on macOS, and allocated about four times as much to show a new text on iOS. Text now fills the size measured for it, and in a text node that isn't editable, a paragraph without a writing direction takes the direction of its first character with a strong direction, as with TextKit 2, so right-to-left text also aligns to the right on the systems before those versions. In an editable text node, such a paragraph aligns by the user's language, like the paragraphs that the user types and as in other TextKit 1 text views. Writing Tools shows its results for an editable text node in a panel instead of in the text, as it does for TextKit 1 text views.
- Text is measured as text views lay it out. It's as wide as its widest line with the line's indents, so a text with paragraphs in both writing directions, or with a truncated last line, is no longer measured wider than its lines. A right-to-left paragraph without a writing direction is measured in its direction, which can make it a few points wider. One line of text is measured with TextKit instead of Core Text, so its height no longer differs from the text view's, by a point or more with some fonts, such as the 16 and 17 point system fonts on macOS, and its line height settings, indents, baseline offsets and attachments no longer clip or truncate it. On iOS, tvOS and visionOS, a line of characters that its font doesn't have, such as Devanagari or Thai in the system font, is measured as tall as text views lay it out, in the font's line height instead of the taller substitute font's.
- On macOS, view frame changes no longer get slower as text views come and go. AppKit registers each text view for the frame changes of every view whenever it moves to a superview, even while it deallocates, so each frame change in the app called into every text view shown and scanned a registration for every text view gone. `BaseTextView` removes that registration, except under a clip view, which also removes a subclass's registration of itself for `NSView.frameDidChangeNotification`, so a subclass observes frame changes with another object.
- Laying out new text is faster: on the main thread, text is measured in one TextKit text system, one text after another, instead of in a new text system for each text, which takes 13% less time and less than half the allocations for new labels. The text system keeps the last text it measures until the end of the run loop turn.
- Scrolling labels into view allocates 10% less: a text color that's the same in both themes, such as a label's default color, is set on the text as it is, and a text view shows a text without themed attributes as it is, instead of as a copy with the theme applied, which the text view copied again.
- Showing and scrolling labels and other text that isn't selectable is faster, especially on iOS, where making a text view selectable or not rebuilds its interactions: a text view is reused only by a text node with the same editable and selectable settings, and keeps them when it's reset for reuse.
- Scrolling labels is faster on iOS: a text node sets a UIKit text view's number of lines, line break mode and inset before its text, while a new or reused text view is still empty, instead of after it, which takes 17% fewer instructions and 20% fewer allocations for rows of labels.
- Scrolling text is faster on macOS: a text view that a text node resets for reuse keeps its number of lines, line break mode and inset, which the next text node sets again, leaves an empty selection where it is, and keeps its text until the end of the run loop turn, so a text view reused in the same render pass replaces its text in one edit instead of two, which takes 28% fewer instructions and 26% fewer allocations for rows of labels. On iOS and tvOS, it keeps the same settings and its text too, except that a reuse that resizes it removes the text first, since resizing a UIKit text view lays out its text again at once.
- Scrolling text is faster on iOS, tvOS and visionOS: the text view of a text node that isn't editable doesn't scroll, as on macOS, so it no longer runs a scroll view's bookkeeping on each frame and text change, which takes 10% to 12% fewer instructions and 8% to 10% fewer allocations for rows of labels on iOS and tvOS. In a frame smaller than its text, such a text node's text stops at its bounds, where a truncating line break mode truncates its last line, as on macOS, instead of going on past them, scrollable. An editable text node still scrolls.
- Fixed a text node sized to fit its text's width, such as with `fixedSize()`, wrapping or cutting off its text when it has a horizontal text container inset: its width now includes the inset on each side, as its height does. On macOS, `BaseTextView`'s intrinsic content size now includes its text container inset, with its text measured in the width inside the inset, as on iOS, tvOS and visionOS.
- When the view or layer type of a renderable item changes under the same id, such as a `ViewNode` of another view class, `ComposeView` replaces its renderable with one of the new type, without the item's transitions, instead of crashing when it updates the renderable of the old type.
- A `ComposeView` that's released while its items animate out deallocates right away, instead of staying until their removal transitions complete. Like the view's other items, those items don't get their `onRemove` blocks called, and their views and layers don't go back to the reuse pool.
- Scrolling is faster: a render pass keeps the `zPosition` of the layers whose items keep their places, instead of giving every shown layer a new one on each scroll step, which in a window made Core Animation copy each layer again. Scrolling rows of labels in a window takes 3% to 4% fewer instructions and 8% to 16% fewer allocations, and scrolling rows of colors takes 5% to 8% fewer instructions.
- Scrolling is faster: a render pass adds each new view where it belongs in the subview order, instead of adding it in front and moving it below the reused views afterward, and checks whether the reused items kept their order while it matches them, instead of in another pass that looks up each item's id. Scrolling rows of colors takes 5% to 8% fewer instructions and rows of labels in a window about 1% fewer, and each scroll step makes 5 to 7 fewer allocations.
- Scrolling labels is faster on macOS: a label draws its text in a Core Animation layer of its own, instead of through AppKit's drawing of the view, when the layer draws the same pixels, which the label drawing parity tests verify for each style that a label draws this way, at a size of whole pixels, on the macOS versions that they pass on. Rows of labels in a window take 28% fewer instructions and 40% fewer allocations to scroll. A text with a style that the tests don't verify, such as a strikethrough, an emoji, a background color or an attachment, keeps AppKit's drawing.
- Scrolling labels in a window is faster on macOS: a `ComposeView` draws the labels about to scroll in ahead of time on background threads, up to a view height or width past its visible bounds along each axis that it scrolls on, and a label that scrolls in shows the image drawn for its text, settings, size and window instead of drawing its text on the main thread. This applies to the labels that draw their text in a layer of their own. A label without such an image draws its text itself, in the same pixels. Rows of labels in a window take about 38% fewer instructions and 40% fewer allocations on the main thread to scroll. A text's dynamic colors, including the colors that an app makes with `NSColor(name:dynamicProvider:)`, can now resolve on those threads, so a dynamic provider must be safe to call off the main thread.
- Reordering views is faster, most on iOS and tvOS: a render pass moves each view to the front without reading its superview's subviews first.
- Scrolling labels is faster on macOS: the cache of label images drawn ahead of time evicts its oldest image without searching all of them.
- Scrolling labels is faster on iOS, tvOS and visionOS: a label lays out its text once, when it draws, instead of each time its text, number of lines, line break mode or size changes, since a UIKit layout manager lays out its text again at once.

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
