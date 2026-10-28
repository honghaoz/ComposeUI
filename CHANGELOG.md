# CHANGELOG

## Unreleased

### Breaking Changes

- With the default animation behavior, bounds changes no longer animate the updates of reused renderables, and insert and remove transitions run on resizes and the first layout as well as on scrolls. Refreshes still choose with their `animated` flag. ([#24](https://github.com/honghaoz/ComposeUI/pull/24))
- Replaced `ComposeView.RenderType.scroll` with `.boundsChange(previousBounds:bounds:)`, and merged `RenderableUpdateType.scroll` into `.boundsChange`. A scroll is a bounds change that keeps the size. ([#24](https://github.com/honghaoz/ComposeUI/pull/24))
- Removed `RenderableUpdateType.requiresFullUpdate`. Handle each update type as the renderable needs. ([#14](https://github.com/honghaoz/ComposeUI/pull/14))
- Drop and inner shadow paths follow the renderable's size instead of the viewport's, and their path providers receive the shadow's size. `DropShadowLayer.update(...)` and `InnerShadowLayer.update(...)` take `paths` or `path`, like the nodes. Request a refresh when the paths' other inputs change. ([#24](https://github.com/honghaoz/ComposeUI/pull/24), [#49](https://github.com/honghaoz/ComposeUI/pull/49))
- Resizing a `ComposeView` lays out its content without evaluating the content builder again. Call `refresh()` or `setNeedsRefresh()` to apply changed configuration. ([#14](https://github.com/honghaoz/ComposeUI/pull/14))
- `SwiftUIViewNode` evaluates its dynamic content when it's first needed, and keeps it until the next refresh. ([#14](https://github.com/honghaoz/ComposeUI/pull/14))
- Removed `LayoutCacheNode`. ([#14](https://github.com/honghaoz/ComposeUI/pull/14))
- Delayed animations are scheduled with Core Animation's `beginTime` instead of a timer. ([#5](https://github.com/honghaoz/ComposeUI/pull/5), [#10](https://github.com/honghaoz/ComposeUI/pull/10))
- A zero-duration transition calls its completion, as does a transition whose animation ends early. ([#10](https://github.com/honghaoz/ComposeUI/pull/10))
- `RenderableTransition.opacity`'s `to` is optional. Without it, the fade ends at the opacity that the content sets. ([#74](https://github.com/honghaoz/ComposeUI/pull/74))
- Removed `ScrollViewType`, and `ScrollView` has UIKit's scroll view API on macOS too: `contentOffset` replaces `contentOffset()` and `setContentOffset(_:)`, `contentSize` replaces `contentSize()` and `setContentSize(_:)`, `adjustedContentInset` replaces `contentInsets()`, `contentInset` replaces `setContentInsets(_:)`, `contentOffset` with `visibleSize` replace `bounds()`, and `isScrollEnabled` replaces `BaseScrollView.isScrollable`, also in the `renderDidUpdateScrollableBehavior` debug event. On macOS, setting `contentOffset` doesn't clamp the offset into the scrollable range. Replace `setBounds(_:)` with setting `frame.size`, then `contentOffset`. `contentView()` and `documentView()` are no longer public: use `documentView` on macOS, and the scroll view itself elsewhere. ([#105](https://github.com/honghaoz/ComposeUI/pull/105), [#106](https://github.com/honghaoz/ComposeUI/pull/106), [#114](https://github.com/honghaoz/ComposeUI/pull/114))
- On macOS, `ComposeView` lays out its content beside legacy scroll bars instead of under them, so render bounds match `visibleSize`, `onWillLayout` can run more than once in a render pass, and `tile()` is final. ([#113](https://github.com/honghaoz/ComposeUI/pull/113))
- On macOS, `ComposeView` no longer supports automatic content insets, magnification, borders, rulers, the find bar or auto-hiding scroll bars. Changing them asserts and keeps the default, and they're final. ([#109](https://github.com/honghaoz/ComposeUI/pull/109), [#113](https://github.com/honghaoz/ComposeUI/pull/113), [#118](https://github.com/honghaoz/ComposeUI/pull/118))
- `ComposeView` lays out, centers and scrolls its content within its content insets, and `sizeThatFits(_:)` includes them. ([#116](https://github.com/honghaoz/ComposeUI/pull/116))
- A `VStack` or `HStack` laid out again at the same size with the same `ComposeNodeLayoutContext` returns its earlier layout, so lay out changed content with a new context, as `ComposeView` does for each render pass. Create and use a context on the main thread, since creating one elsewhere asserts in debug builds. ([#128](https://github.com/honghaoz/ComposeUI/pull/128))
- `ComposeView` keeps its content's layout through a resize, and a `VStack` or `HStack` keeps its layout when laid out again in a pass, at a size that differs only in lengths that the layout didn't read, which each node reports in its sizing's `dependence`. A custom node that returns its child's `ComposeNodeSizing` passes on the child's `dependence`, so if it also reads the container size itself, such as to pick a child by width or height, add those lengths: `ComposeNodeSizing(width: sizing.width, height: sizing.height, dependence: sizing.dependence.union(.height))`. Debug builds lay out again where a layout would be kept at another size, and assert if the two layouts differ in sizing, in size, or in the bounds of their items, which finds such a node. ([#244](https://github.com/honghaoz/ComposeUI/pull/244), [#246](https://github.com/honghaoz/ComposeUI/pull/246))
- On macOS, setting `BaseTextView`'s text to an equal text leaves it in place, as on iOS, so a refresh keeps the selection. To change an attribute object, such as an attachment's image, set a text with a new object. ([#129](https://github.com/honghaoz/ComposeUI/pull/129))
- Replaced `ComposeContent.asNodes()` with the `nodes` property, and removed `ComposeContentBuilder.Item`: the builder's methods take and return `_Node`, `_Content` and `_Component`. A type that implemented `asNodes()` becomes a node, or a property or function marked `@ComposeContentBuilder`. An app's own builder method returns the `_Content` of one of the builder's methods, such as `buildExpression(_:)`, or its type becomes a node. ([#136](https://github.com/honghaoz/ComposeUI/pull/136), [#225](https://github.com/honghaoz/ComposeUI/pull/225))
- `ComposeNode` requires `render(visibleBounds:into:)` instead of `renderableItems(in:)`. To migrate a node, rename its implementation, append its items to the given array instead of returning them, and have its children append to the same array before adjusting the items they appended. Don't keep the old method, since calls on the node's own type would still use it. ([#188](https://github.com/honghaoz/ComposeUI/pull/188))
- `ComposeView.theme` stays the same during a render pass. Setting `overrideTheme` during the view's own render pass asserts, and it's final. ([#144](https://github.com/honghaoz/ComposeUI/pull/144))
- A text node's text that's neither editable nor selectable, as a label's by default, shows in a new `TextLabelView` instead of a `BaseTextView`, in the same pixels with much less work. Code that casts a label's view gets a `TextLabelView`. To keep a text view, make the text selectable. ([#183](https://github.com/honghaoz/ComposeUI/pull/183), [#185](https://github.com/honghaoz/ComposeUI/pull/185), [#236](https://github.com/honghaoz/ComposeUI/pull/236))
- A render pass reuses the label and text views of `TextNode` and `LabelNode` in place for new nodes of the same kind, instead of removing them and taking them from the reuse pool, so their superview and window callbacks don't run. A view gives up the first responder in it, and a view with a touch or the focus, or on macOS any view while a mouse button is pressed, is removed as before. An app's view can opt in with `reuseId(_:inPlace: true)`. On macOS, up to 8 unused label views stay hidden in the compose view for later rows. A custom `RenderablePoolType` doesn't see the views reused in place. ([#203](https://github.com/honghaoz/ComposeUI/pull/203), [#212](https://github.com/honghaoz/ComposeUI/pull/212), [#233](https://github.com/honghaoz/ComposeUI/pull/233))
- Methods that return a changed node, such as `LabelNode.font(_:)`, consume the node, so a call on a `borrowing` parameter needs a copy: `(copy node).font(font)`. ([#219](https://github.com/honghaoz/ComposeUI/pull/219))
- `TextNode` defaults to a label's font and text color, so unstyled text looks the same in a text node as in a label: 13 points in the label color on macOS and 20 points on tvOS, unchanged on iOS and visionOS. To keep the old look, pass `font: .systemFont(ofSize: 17)` and `foregroundColor: ThemedColor(light: .black, dark: .white)`. ([#223](https://github.com/honghaoz/ComposeUI/pull/223))
- Building ComposeUI requires Swift 6.0, which Xcode 16 has. The package still builds in the Swift 5 language mode. ([#225](https://github.com/honghaoz/ComposeUI/pull/225))
- Renamed `ComposeNode.renderableItemsBoundingRect` to `renderableItemsBounds`. To migrate a node, rename its implementation: one under the old name still builds, but isn't read, so items that the node places outside its bounds can be left out of a render. ([#251](https://github.com/honghaoz/ComposeUI/pull/251))
- The node owns its renderable's transform: the render pass no longer resets it to identity on each pass, so a transform set in any block stays until the node changes it. A node that sets a transform only while a condition holds sets the identity transform when it doesn't. The frame is where the position and bounds size place the renderable, before the transform applies, which `Renderable.frame` returns, and a renderable that the render pass reuses for another item starts with an identity transform. ([#270](https://github.com/honghaoz/ComposeUI/pull/270))

### Changes

- Added `previousRenderBounds` and `renderBounds` to `RenderableUpdateContext`, which tell a scroll from a resize. ([#24](https://github.com/honghaoz/ComposeUI/pull/24))
- Added a scale transition, `.scale(from:anchor:timing:options:)`, whose anchor is a `UnitPoint`, a type that moved from ChouTiUI. ([#10](https://github.com/honghaoz/ComposeUI/pull/10), [#255](https://github.com/honghaoz/ComposeUI/pull/255))
- Added `InsertTransition.prepareForTakeover(renderable:)`, and `revivalPosition` and `revivalTransform` in the insert transition context, for transitions that take over a removal. Slide and spring opacity transitions continue a revival from where the removal left off. ([#6](https://github.com/honghaoz/ComposeUI/pull/6), [#10](https://github.com/honghaoz/ComposeUI/pull/10), [#74](https://github.com/honghaoz/ComposeUI/pull/74))
- Added `CALayer.retarget(keyPath:to:)`, which sets a property and continues its in-flight animations toward the new value. ([#48](https://github.com/honghaoz/ComposeUI/pull/48))
- Added a `transform(_:anchor:)` modifier, which transforms a node's renderables about a point of each, the same point on every platform, without changing their layout. A new transform applies at once, and a transform follows an animated resize of its renderable. ([#271](https://github.com/honghaoz/ComposeUI/pull/271))
- Added `dependence` to `ComposeNodeSizing`, the lengths of the container size that a node's layout reads. A custom node that reports only the lengths it reads, such as `.width` for content that wraps in the container's width, lets `ComposeView` keep its layout when only another length changes. A sizing made without it depends on both lengths. ([#244](https://github.com/honghaoz/ComposeUI/pull/244))
- `DropShadowLayer` and `InnerShadowLayer` can be created and subclassed outside the framework. ([#44](https://github.com/honghaoz/ComposeUI/pull/44))
- A nested compose view, in a `ComposeViewNode` or a `ViewNode`, updates and lays out within its parent's render pass, and animates no more than the parent's pass allows. Set its properties in `willInsert` or `willUpdate`, since `onInsert` and `onUpdate` run after its first render. ([#14](https://github.com/honghaoz/ComposeUI/pull/14), [#29](https://github.com/honghaoz/ComposeUI/pull/29), [#30](https://github.com/honghaoz/ComposeUI/pull/30))
- A render pass requested during another view's render pass, and a bounds change made during the view's own render pass, render after that pass. ([#30](https://github.com/honghaoz/ComposeUI/pull/30))
- `AnimationBehavior.dynamic` is called once per render pass instead of once per renderable. ([#24](https://github.com/honghaoz/ComposeUI/pull/24))
- `ComposeView` renders again when the display scale changes on iOS and tvOS, as on macOS. ([#10](https://github.com/honghaoz/ComposeUI/pull/10))
- Coalesced `setNeedsRefresh(animated:)` requests refresh without animation when any of them asked for none. ([#8](https://github.com/honghaoz/ComposeUI/pull/8), [#10](https://github.com/honghaoz/ComposeUI/pull/10))
- Animations are smoother: a reused renderable with an unchanged frame doesn't animate, a non-animated update continues in-flight animations toward the new values instead of jumping, updates animate only the properties that changed, stacked modifiers of one property apply only the outermost, and drop and inner shadow paths animate with the frame. ([#39](https://github.com/honghaoz/ComposeUI/pull/39), [#42](https://github.com/honghaoz/ComposeUI/pull/42), [#49](https://github.com/honghaoz/ComposeUI/pull/49), [#68](https://github.com/honghaoz/ComposeUI/pull/68), [#72](https://github.com/honghaoz/ComposeUI/pull/72), [#74](https://github.com/honghaoz/ComposeUI/pull/74), [#76](https://github.com/honghaoz/ComposeUI/pull/76), [#121](https://github.com/honghaoz/ComposeUI/pull/121))
- Animations begin at a time read once per turn of the main run loop. A test that compares animations with the media time should turn the run loop first. ([#87](https://github.com/honghaoz/ComposeUI/pull/87))
- Debug builds assert on invalid `AnimationTiming` values, which fall back to defaults. ([#62](https://github.com/honghaoz/ComposeUI/pull/62))
- `oldFrame` in a reused renderable's update context, and in the remove context, is the `newFrame` of the renderable's previous update, so the two are equal when the frame didn't change, instead of differing by floating-point noise on 3x displays. A frame that something else set on the renderable no longer shows in `oldFrame`. ([#269](https://github.com/honghaoz/ComposeUI/pull/269))
- On macOS, scrolling no longer shifts content that fits the view by a pixel, a trackpad scroll stays with its scroll view until its glide ends, and a mouse wheel scrolls the innermost scroll view that can scroll in its direction. ([#114](https://github.com/honghaoz/ComposeUI/pull/114), [#119](https://github.com/honghaoz/ComposeUI/pull/119))
- On macOS, view frame changes no longer slow down as text views come and go. A `BaseTextView` subclass observes `NSView.frameDidChangeNotification` with another object, since `BaseTextView` removes its own registration. ([#160](https://github.com/honghaoz/ComposeUI/pull/160))
- On macOS, labels draw ahead of time on background threads, so a color made with `NSColor(name:dynamicProvider:)` must be safe to call off the main thread. ([#196](https://github.com/honghaoz/ComposeUI/pull/196))
- Text views lay out their text with TextKit 1, as ComposeUI measures it, so measured sizes match what they draw. Right-to-left text without a writing direction aligns to the right on all systems, a paragraph in an editable text node aligns by the user's language, and Writing Tools shows its results for an editable text node in a panel. ([#160](https://github.com/honghaoz/ComposeUI/pull/160))
- On iOS, tvOS and visionOS, the text view of a text node that isn't editable doesn't scroll: text larger than its frame stops at its bounds, as on macOS. ([#172](https://github.com/honghaoz/ComposeUI/pull/172))
- Fixed a text node sized to its text, such as with `fixedSize()`, wrapping its text when it has a horizontal inset. On macOS, `BaseTextView`'s intrinsic content size includes its inset. ([#184](https://github.com/honghaoz/ComposeUI/pull/184))
- Fixed a render pass without an `onWillRender` handler dropping items after a change of the content size. ([#24](https://github.com/honghaoz/ComposeUI/pull/24))
- Fixed a stack that never finished its layout in release builds when a child has an infinite fixed size. Use `.flexible` to fill the space. ([#150](https://github.com/honghaoz/ComposeUI/pull/150))
- Changing the view or layer type of an item under the same id replaces its renderable instead of crashing. ([#179](https://github.com/honghaoz/ComposeUI/pull/179))
- A `ComposeView` released while its items animate out deallocates right away, without calling their `onRemove` blocks. ([#182](https://github.com/honghaoz/ComposeUI/pull/182))
- Fixed `CALayer.animate` crashing, losing the change or dropping the layer's transform for a geometry key path, such as `position.x`, on a view-backed layer on macOS. ([#63](https://github.com/honghaoz/ComposeUI/pull/63))

### Performance

- Scrolling and refreshing labels and text are much faster and allocate far less: labels draw in `TextLabelView`, text views lay out with TextKit 1 and keep their settings and text through reuse, and a label lays out its text once, when it draws. ([#132](https://github.com/honghaoz/ComposeUI/pull/132), [#160](https://github.com/honghaoz/ComposeUI/pull/160), [#162](https://github.com/honghaoz/ComposeUI/pull/162), [#163](https://github.com/honghaoz/ComposeUI/pull/163), [#164](https://github.com/honghaoz/ComposeUI/pull/164), [#165](https://github.com/honghaoz/ComposeUI/pull/165), [#166](https://github.com/honghaoz/ComposeUI/pull/166), [#172](https://github.com/honghaoz/ComposeUI/pull/172), [#173](https://github.com/honghaoz/ComposeUI/pull/173), [#183](https://github.com/honghaoz/ComposeUI/pull/183), [#208](https://github.com/honghaoz/ComposeUI/pull/208))
- On macOS, labels draw in a layer of their own, skip AppKit's display pass, layout pass and frame-change notifications, and free the images that they replace off the main thread. ([#191](https://github.com/honghaoz/ComposeUI/pull/191), [#195](https://github.com/honghaoz/ComposeUI/pull/195), [#196](https://github.com/honghaoz/ComposeUI/pull/196), [#206](https://github.com/honghaoz/ComposeUI/pull/206), [#233](https://github.com/honghaoz/ComposeUI/pull/233), [#235](https://github.com/honghaoz/ComposeUI/pull/235), [#236](https://github.com/honghaoz/ComposeUI/pull/236), [#238](https://github.com/honghaoz/ComposeUI/pull/238), [#263](https://github.com/honghaoz/ComposeUI/pull/263), [#265](https://github.com/honghaoz/ComposeUI/pull/265), [#266](https://github.com/honghaoz/ComposeUI/pull/266))
- Render passes are faster: views are reused in place, layers keep their order, new views go straight to their place, render items change in place, a view reuses the item ids that built-in stacks and modifiers made in earlier passes instead of making them again, and checking a reused renderable's frame takes half the calls into Core Animation. A built-in node made in a layout keeps its render item until the content refreshes, so make a custom node's child nodes once and keep them across layouts. ([#148](https://github.com/honghaoz/ComposeUI/pull/148), [#151](https://github.com/honghaoz/ComposeUI/pull/151), [#152](https://github.com/honghaoz/ComposeUI/pull/152), [#155](https://github.com/honghaoz/ComposeUI/pull/155), [#189](https://github.com/honghaoz/ComposeUI/pull/189), [#190](https://github.com/honghaoz/ComposeUI/pull/190), [#203](https://github.com/honghaoz/ComposeUI/pull/203), [#205](https://github.com/honghaoz/ComposeUI/pull/205), [#245](https://github.com/honghaoz/ComposeUI/pull/245), [#247](https://github.com/honghaoz/ComposeUI/pull/247), [#257](https://github.com/honghaoz/ComposeUI/pull/257), [#269](https://github.com/honghaoz/ComposeUI/pull/269))
- Building content is faster: `@ComposeContentBuilder` and stacks keep nodes by value instead of boxing them, built-in modifiers are inlinable and store their values, and the methods that return a changed node change it in place. Return rows as `some ComposeNode` where possible, since an `any ComposeNode` row is copied out of its box. ([#134](https://github.com/honghaoz/ComposeUI/pull/134), [#153](https://github.com/honghaoz/ComposeUI/pull/153), [#154](https://github.com/honghaoz/ComposeUI/pull/154), [#157](https://github.com/honghaoz/ComposeUI/pull/157), [#214](https://github.com/honghaoz/ComposeUI/pull/214), [#216](https://github.com/honghaoz/ComposeUI/pull/216), [#219](https://github.com/honghaoz/ComposeUI/pull/219), [#221](https://github.com/honghaoz/ComposeUI/pull/221), [#226](https://github.com/honghaoz/ComposeUI/pull/226), [#231](https://github.com/honghaoz/ComposeUI/pull/231))
- Laying out content is faster: stacks lay out faster, nested stacks with flexible children no longer repeat their children's layouts at each level, content laid out again at a size that differs only in a length its layout doesn't depend on, such as the height of a list of fixed rows, keeps its layout, including when the view resizes, and text measurement reuses its text system and the sizes it measured. ([#128](https://github.com/honghaoz/ComposeUI/pull/128), [#131](https://github.com/honghaoz/ComposeUI/pull/131), [#138](https://github.com/honghaoz/ComposeUI/pull/138), [#141](https://github.com/honghaoz/ComposeUI/pull/141), [#142](https://github.com/honghaoz/ComposeUI/pull/142), [#161](https://github.com/honghaoz/ComposeUI/pull/161), [#210](https://github.com/honghaoz/ComposeUI/pull/210), [#218](https://github.com/honghaoz/ComposeUI/pull/218), [#222](https://github.com/honghaoz/ComposeUI/pull/222), [#243](https://github.com/honghaoz/ComposeUI/pull/243), [#244](https://github.com/honghaoz/ComposeUI/pull/244), [#245](https://github.com/honghaoz/ComposeUI/pull/245), [#252](https://github.com/honghaoz/ComposeUI/pull/252), [#253](https://github.com/honghaoz/ComposeUI/pull/253), [#261](https://github.com/honghaoz/ComposeUI/pull/261), [#262](https://github.com/honghaoz/ComposeUI/pull/262))
- Refreshing colors and themed content is faster on macOS, and layer animations start with fewer copies. ([#144](https://github.com/honghaoz/ComposeUI/pull/144), [#146](https://github.com/honghaoz/ComposeUI/pull/146), [#147](https://github.com/honghaoz/ComposeUI/pull/147), [#232](https://github.com/honghaoz/ComposeUI/pull/232))

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
