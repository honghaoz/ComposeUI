//
//  RenderItemTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/25/26.
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

import ChouTiTest

@testable import ComposeUI

class RenderItemTests: XCTestCase {

  // MARK: - Update Blocks

  func test_update_withoutAddedBlocks_runsTheItemsOwnBlock() {
    // given: an item with only its own update block
    let item = makeItem()

    // then: reading the update block and the render pass's update both run the item's own block
    expect(appliedTokens(of: item, byReadingTheBlock: true)) == ["own"]
    expect(appliedTokens(of: item)) == ["own"]
  }

  func test_addUpdate_runsTheBlocksInOrder() {
    // given: an item with two added update blocks
    let item = makeItem()
      .addUpdate(appendingToken("a"))
      .addUpdate(appendingToken("b"))

    // then: the item's own block runs first, then the added ones in order, whether the update block is read or the
    // render pass runs the update
    expect(appliedTokens(of: item, byReadingTheBlock: true)) == ["own", "a", "b"]
    expect(appliedTokens(of: item)) == ["own", "a", "b"]
  }

  func test_addUpdates_keyedBlock_replacesTheEarlierBlockOfTheSameKey() {
    // given: an item with a keyed block, an unkeyed block and a block of another key
    let item = makeItem().addUpdates(updateList(
      keyedUpdate(.opacity, appendingToken("opacity 1")),
      keyedUpdate(nil, appendingToken("unkeyed")),
      keyedUpdate(.border, appendingToken("border"))
    ))

    // when: another block with the first block's key is added
    let updatedItem = item.addUpdates(updateList(keyedUpdate(.opacity, appendingToken("opacity 2"))))

    // then: the new block replaces the earlier one and runs at its own position, and the other blocks are kept
    expect(appliedTokens(of: updatedItem)) == ["own", "unkeyed", "border", "opacity 2"]

    // then: the original item keeps its blocks
    expect(appliedTokens(of: item)) == ["own", "opacity 1", "unkeyed", "border"]
  }

  func test_additionalUpdates_keepTheLastBlockOfEachKey() {
    // given: lists built the way coalesced modifiers build them, with a single block stored apart from an array of
    // blocks
    let cases: [(name: String, list: RenderableItem.AdditionalUpdates, expectedTokens: [String])] = [
      (
        "one block, then a block of its key",
        updateList(
          keyedUpdate(.opacity, appendingToken("opacity 1")),
          keyedUpdate(.opacity, appendingToken("opacity 2"))
        ),
        ["own", "opacity 2"]
      ),
      (
        "one block, then a block of another key",
        updateList(
          keyedUpdate(.opacity, appendingToken("opacity")),
          keyedUpdate(.border, appendingToken("border"))
        ),
        ["own", "opacity", "border"]
      ),
      (
        "one unkeyed block, then a keyed block",
        updateList(
          keyedUpdate(nil, appendingToken("unkeyed")),
          keyedUpdate(.opacity, appendingToken("opacity"))
        ),
        ["own", "unkeyed", "opacity"]
      ),
      (
        "several blocks, then a block of the first one's key",
        updateList(
          keyedUpdate(.opacity, appendingToken("opacity 1")),
          keyedUpdate(nil, appendingToken("unkeyed")),
          keyedUpdate(.opacity, appendingToken("opacity 2"))
        ),
        ["own", "unkeyed", "opacity 2"]
      ),
      (
        "several blocks, then a block of a later one's key",
        updateList(
          keyedUpdate(.border, appendingToken("border")),
          keyedUpdate(.opacity, appendingToken("opacity 1")),
          keyedUpdate(.opacity, appendingToken("opacity 2"))
        ),
        ["own", "border", "opacity 2"]
      ),
    ]

    for testCase in cases {
      // then: only the last block of each key runs, at its own position
      expect(appliedTokens(of: makeItem().addUpdates(testCase.list)), testCase.name) == testCase.expectedTokens
    }
  }

  func test_addUpdates_emptyList_keepsTheItemsBlocks() {
    // given: an item with an added block
    let item = makeItem().addUpdates(updateList(keyedUpdate(.opacity, appendingToken("opacity"))))

    // when: an empty list is added
    let updatedItem = item.addUpdates(.none)

    // then: the item's blocks are unchanged
    expect(appliedTokens(of: updatedItem)) == ["own", "opacity"]
  }

  func test_addUpdate_unkeyedBlocks_areNeverReplaced() {
    // given: an item with a keyed block
    let item = makeItem().addUpdates(updateList(keyedUpdate(.opacity, appendingToken("opacity"))))

    // when: unkeyed blocks are added
    let updatedItem = item
      .addUpdate(appendingToken("a"))
      .addUpdates(updateList(keyedUpdate(nil, appendingToken("b")), keyedUpdate(nil, appendingToken("c"))))

    // then: every block runs
    expect(appliedTokens(of: updatedItem)) == ["own", "opacity", "a", "b", "c"]
  }

  func test_update_blocksTakingEitherRenderableType_runInOrder() {
    // given: an item with blocks that take a `Renderable`, as modifiers add them, around a block that takes the item's
    // renderable type, as `addUpdate(_:)` adds it
    let item = makeItem()
      .addUpdates(updateList(
        keyedUpdate(.opacity, appendingToken("opacity 1")),
        keyedUpdate(nil, appendingToken("a"))
      ))
      .addUpdate(appendingToken("b"))
      .addUpdates(updateList(keyedUpdate(.opacity, appendingToken("opacity 2"))))

    // then: the blocks run in order and the later keyed block replaces the earlier one, whether the update block is read
    // or the render pass runs the update
    expect(appliedTokens(of: item, byReadingTheBlock: true)) == ["own", "a", "b", "opacity 2"]
    expect(appliedTokens(of: item)) == ["own", "a", "b", "opacity 2"]
  }

  func test_additionalUpdates_nodeFitsA64ByteAllocation() {
    // then: a list node, a 16-byte object header followed by a block and the rest of the list, fits a 64-byte
    // allocation, which a block's key stored before the block would outgrow through padding
    let nodePayloadSize = MemoryLayout<RenderableItem.AdditionalUpdate>.stride + MemoryLayout<RenderableItem.AdditionalUpdates>.size
    expect(16 + nodePayloadSize) <= 64
  }

  func test_otherBuilders_keepTheAddedBlocksAndTheirKeys() {
    let builders: [(name: String, build: (RenderableItem) -> RenderableItem)] = [
      ("addWillInsert", { $0.addWillInsert { _, _ in } }),
      ("addDidInsert", { $0.addDidInsert { _, _ in } }),
      ("addWillUpdate", { $0.addWillUpdate { _, _ in } }),
      ("addWillRemove", { $0.addWillRemove { _, _ in } }),
      ("addDidRemove", { $0.addDidRemove { _, _ in } }),
      ("reuseId(String)", { $0.reuseId("reuse") }),
      ("reuseId(ReuseId)", { $0.reuseId(ReuseId(namespace: .framework, id: "reuse")) }),
      ("addResetForReuse", { $0.addResetForReuse { _ in } }),
      ("transition", { $0.transition(.opacity()) }),
      ("animation", { $0.animation(.easeInEaseOut(duration: 1)) }),
      ("zIndex", { $0.zIndex(1) }),
    ]

    for builder in builders {
      // given: an item with a keyed block and an unkeyed block, passed through the builder
      let item = builder.build(makeItem().addUpdates(updateList(
        keyedUpdate(.opacity, appendingToken("opacity 1")),
        keyedUpdate(nil, appendingToken("unkeyed"))
      )))

      // when: another block with the same key is added
      let updatedItem = item.addUpdates(updateList(keyedUpdate(.opacity, appendingToken("opacity 2"))))

      // then: the builder kept the blocks and the key, so the new block replaces the earlier one
      expect(appliedTokens(of: updatedItem), builder.name) == ["own", "unkeyed", "opacity 2"]
    }
  }

  func test_eraseToRenderableItem_runsTheAddedBlocks() {
    // given: a view item and a layer item with an added update block
    let viewItem = ViewItem<BaseView>(
      id: .custom("view"),
      frame: .zero,
      make: { _ in BaseView() },
      update: { view, _ in view.layer().name = "own" }
    )
    .addUpdate { view, _ in view.layer().name = (view.layer().name ?? "") + ",added" }

    let layerItem = LayerItem<CALayer>(
      id: .custom("layer"),
      frame: .zero,
      make: { _ in CALayer() },
      update: { layer, _ in layer.name = "own" }
    )
    .addUpdate { layer, _ in layer.name = (layer.name ?? "") + ",added" }

    // when: the items are erased and updated
    let view = BaseView()
    let layer = CALayer()
    withUpdateContext { context in
      viewItem.eraseToRenderableItem().performUpdate(.view(view), context)
      layerItem.eraseToRenderableItem().performUpdate(.layer(layer), context)
    }

    // then: the erased items run the items' own blocks and the added ones
    expect(view.layer().name) == "own,added"
    expect(layer.name) == "own,added"
  }

  // MARK: - Running Blocks

  func test_renderPass_runsTheItemsBlocks() {
    // given: an item made with every block
    let item = makeTokenItem { Renderable.layer(CALayer()) }

    withContexts { contexts in
      // when: the render pass makes a renderable with the item and runs its blocks
      let renderable = item.makeRenderable(contexts.make)
      runBlocksAsTheRenderPass(of: item, with: renderable, contexts)

      // then: the blocks ran in turn on the renderable the item made
      expect(tokens(of: renderable)) == Self.blockNames
    }
  }

  func test_readingTheBlocks_runsTheItemsBlocks() {
    // given: an item made with every block
    let item = makeTokenItem { Renderable.layer(CALayer()) }

    withContexts { contexts in
      // when: making a renderable and running the blocks read from the item
      let renderable = item.make(contexts.make)
      runBlocksByReadingThem(of: item, with: renderable, contexts)

      // then: the blocks ran in turn on the renderable the item made
      expect(tokens(of: renderable)) == Self.blockNames
    }
  }

  func test_transitionAndAnimation_keepTheItemsOwn() {
    // given: an item with a transition and an animation
    let item = makeItem()
      .transition(.opacity())
      .animation(.easeInEaseOut(duration: 1))

    // when: setting another transition and animation
    let updatedItem = item
      .transition(RenderableTransition(insert: nil, remove: nil))
      .animation(.linear(duration: 2))

    // then: the item keeps its own, which a node closer to the leaf set
    expect(updatedItem.transition?.insert).toNot(beNil())
    expect(updatedItem.animationTiming) == .easeInEaseOut(duration: 1)
  }

  func test_eraseToRenderableItem_renderPass_runsTheItemsBlocks() {
    for (kind, item) in erasedTokenItems {
      withContexts { contexts in
        // when: the render pass makes a renderable with an erased item, whose view or layer item has every block, and
        // runs its blocks
        let renderable = item.makeRenderable(contexts.make)
        runBlocksAsTheRenderPass(of: item, with: renderable, contexts)

        // then: the item made a renderable of its kind, and its blocks ran in turn on it
        expect(renderable.view != nil, kind) == (kind == "view")
        expect(tokens(of: renderable), kind) == Self.blockNames
      }
    }
  }

  func test_eraseToRenderableItem_readingTheBlocks_runsTheItemsBlocks() {
    for (kind, item) in erasedTokenItems {
      withContexts { contexts in
        // when: making a renderable and running the blocks read from an erased item, whose view or layer item has
        // every block
        let renderable = item.make(contexts.make)
        runBlocksByReadingThem(of: item, with: renderable, contexts)

        // then: the item made a renderable of its kind, and its blocks ran in turn on it
        expect(renderable.view != nil, kind) == (kind == "view")
        expect(tokens(of: renderable), kind) == Self.blockNames
      }
    }
  }

  func test_eraseToRenderableItem_itemWithoutBlocks_hasOnlyTheBlocksAddedAfterErasing() {
    // given: an erased layer item with only its make and update blocks
    let item = LayerItem<CALayer>(
      id: .custom("layer"),
      frame: .zero,
      make: { _ in CALayer() },
      update: { layer, _ in Self.appendToken("update", to: layer) }
    )
    .eraseToRenderableItem()

    // then: the erased item has no other blocks
    expect(item.willInsert).to(beNil())
    expect(item.didInsert).to(beNil())
    expect(item.willUpdate).to(beNil())
    expect(item.willRemove).to(beNil())
    expect(item.didRemove).to(beNil())
    expect(item.resetForReuse).to(beNil())

    withContexts { contexts in
      // when: a block of each kind is added to the erased item, and the blocks read from it run
      let itemWithBlocks = addingTokenBlocks(to: item)
      let renderable = itemWithBlocks.make(contexts.make)
      runBlocksByReadingThem(of: itemWithBlocks, with: renderable, contexts)

      // then: the erased item has the added blocks, which ran with the item's update
      expect(tokens(of: renderable)) == [
        "added willInsert", "added didInsert", "added willUpdate", "update", "added update", "added willRemove", "added didRemove", "added resetForReuse",
      ]
    }
  }

  func test_eraseToRenderableItem_addedBlocks_runAfterTheItemsBlocks() {
    // given: an erased item whose layer item has every block, with a block of each kind added after erasing
    let item = addingTokenBlocks(to: makeTokenItem { CALayer() }.eraseToRenderableItem())
    let expectedTokens = [
      "willInsert", "added willInsert",
      "didInsert", "added didInsert",
      "willUpdate", "added willUpdate",
      "update", "added update",
      "willRemove", "added willRemove",
      "didRemove", "added didRemove",
      "resetForReuse", "added resetForReuse",
    ]

    withContexts { contexts in
      // when: the render pass makes a renderable with the item and runs its blocks
      let renderable = item.makeRenderable(contexts.make)
      runBlocksAsTheRenderPass(of: item, with: renderable, contexts)

      // then: each block of the layer item ran before the block of its kind added after erasing
      expect(tokens(of: renderable)) == expectedTokens
    }

    withContexts { contexts in
      // when: running the blocks read from the item
      let renderable = item.make(contexts.make)
      runBlocksByReadingThem(of: item, with: renderable, contexts)

      // then: the blocks ran in the same order
      expect(tokens(of: renderable)) == expectedTokens
    }
  }

  func test_eraseToRenderableItem_keepsTheItemsValues() {
    // given: a view item with a reuse id, a transition, an animation and a z-index
    let item = makeTokenItem { BaseView() }

    // when: erasing the item
    let erasedItem = item.eraseToRenderableItem()

    // then: the erased item has the item's values, and the type of the item's view for reuse
    expect(erasedItem.id) == item.id
    expect(erasedItem.frame) == item.frame
    expect(erasedItem.reuseId) == ReuseId(namespace: .user, id: "reuse")
    expect(erasedItem.renderableType) == ObjectIdentifier(BaseView.self)
    expect(erasedItem.transition).toNot(beNil())
    expect(erasedItem.animationTiming) == .easeInEaseOut(duration: 1)
    expect(erasedItem.zIndex) == 2
  }

  func test_eraseToRenderableItem_builders_keepTheItemsBlocks() {
    // given: an erased view item without a transition, an animation, a z-index and a reuse id
    let item = ViewItem<BaseView>(
      id: .custom("view"),
      frame: .zero,
      make: { _ in Self.makeView() },
      update: { view, _ in Self.appendToken("update", to: view) }
    )
    .eraseToRenderableItem()

    // when: the builders set the values
    let builtItem = item
      .transition(.opacity())
      .animation(.easeInEaseOut(duration: 1))
      .zIndex(3)
      .reuseId("reuse")

    // then: the item has the values, and still makes the view item's views and runs its update
    expect(builtItem.transition).toNot(beNil())
    expect(builtItem.animationTiming) == .easeInEaseOut(duration: 1)
    expect(builtItem.zIndex) == 3
    expect(builtItem.reuseId) == ReuseId(namespace: .user, id: "reuse")
    withContexts { contexts in
      let renderable = builtItem.makeRenderable(contexts.make)
      builtItem.performUpdate(renderable, contexts.update)

      expect(renderable.view is BaseView) == true
      expect(tokens(of: renderable)) == ["update"]
    }
  }

  func test_eraseToRenderableItem_layerItem_takesTheLayerOfAView() {
    // given: an erased layer item
    let item = makeTokenItem { CALayer() }.eraseToRenderableItem()

    // when: running its update with a view
    let view = Self.makeView()
    withContexts { contexts in
      item.performUpdate(.view(view), contexts.update)
    }

    // then: the layer item's update ran on the view's layer, as `Renderable.layer` gives a layer for a view
    expect(view.layer().name) == "update"
  }

  // MARK: - Helpers

  /// The names of an item's blocks other than `make`, in the order `runBlocksAsTheRenderPass(of:with:_:)` runs them.
  private static let blockNames = ["willInsert", "didInsert", "willUpdate", "update", "willRemove", "didRemove", "resetForReuse"]

  /// An erased view item and an erased layer item, by kind, whose items have every block, see `makeTokenItem(make:)`.
  private var erasedTokenItems: [(kind: String, item: RenderableItem)] {
    [
      ("view", makeTokenItem { Self.makeView() }.eraseToRenderableItem()),
      ("layer", makeTokenItem { CALayer() }.eraseToRenderableItem()),
    ]
  }

  /// An item with every block, each appending its name to the renderable's layer name, see `appendToken(_:to:)`, and
  /// with a reuse id, a transition, an animation and a z-index.
  private func makeTokenItem<T>(make: @escaping () -> T) -> RenderItem<T> {
    RenderItem<T>(
      id: .custom("item"),
      frame: CGRect(x: 1, y: 2, width: 3, height: 4),
      make: { _ in make() },
      willInsert: { renderable, _ in Self.appendToken("willInsert", to: renderable) },
      didInsert: { renderable, _ in Self.appendToken("didInsert", to: renderable) },
      willUpdate: { renderable, _ in Self.appendToken("willUpdate", to: renderable) },
      update: { renderable, _ in Self.appendToken("update", to: renderable) },
      willRemove: { renderable, _ in Self.appendToken("willRemove", to: renderable) },
      didRemove: { renderable, _ in Self.appendToken("didRemove", to: renderable) },
      reuseId: "reuse",
      resetForReuse: { renderable in Self.appendToken("resetForReuse", to: renderable) },
      transition: .opacity(),
      animationTiming: .easeInEaseOut(duration: 1),
      zIndex: 2
    )
  }

  /// The item with a block of each kind added, each appending its name, prefixed with "added", to the renderable's
  /// layer name.
  private func addingTokenBlocks(to item: RenderableItem) -> RenderableItem {
    item
      .addWillInsert { renderable, _ in Self.appendToken("added willInsert", to: renderable) }
      .addDidInsert { renderable, _ in Self.appendToken("added didInsert", to: renderable) }
      .addWillUpdate { renderable, _ in Self.appendToken("added willUpdate", to: renderable) }
      .addUpdate { renderable, _ in Self.appendToken("added update", to: renderable) }
      .addWillRemove { renderable, _ in Self.appendToken("added willRemove", to: renderable) }
      .addDidRemove { renderable, _ in Self.appendToken("added didRemove", to: renderable) }
      .addResetForReuse { renderable in Self.appendToken("added resetForReuse", to: renderable) }
  }

  /// A view whose layer has no name, so the layer's name has only the tokens that blocks append, see
  /// `appendToken(_:to:)`, since `BaseView` names its layer after its type.
  private static func makeView() -> BaseView {
    let view = BaseView()
    view.layer().name = nil
    return view
  }

  /// Appends a token to the name of the layer of a renderable, a view or a layer, so the blocks that ran show on the
  /// renderable they ran on.
  private static func appendToken(_ token: String, to renderable: Any) {
    let layer: CALayer
    switch renderable {
    case let renderable as Renderable:
      layer = renderable.layer
    case let view as View:
      layer = view.layer()
    case let renderableLayer as CALayer:
      layer = renderableLayer
    default:
      fail("unexpected renderable \(renderable)")
      return
    }
    layer.name = layer.name.map { "\($0),\(token)" } ?? token
  }

  /// The tokens that the blocks appended to the renderable's layer name, see `appendToken(_:to:)`.
  private func tokens(of renderable: Renderable) -> [String] {
    renderable.layer.name?.components(separatedBy: ",") ?? []
  }

  /// Runs the item's blocks other than `make` through the methods the render pass calls.
  private func runBlocksAsTheRenderPass(of item: RenderableItem, with renderable: Renderable, _ contexts: Contexts) {
    item.performWillInsert(renderable, contexts.insert)
    item.performDidInsert(renderable, contexts.insert)
    item.performWillUpdate(renderable, contexts.update)
    item.performUpdate(renderable, contexts.update)
    item.performWillRemove(renderable, contexts.remove)
    item.performDidRemove(renderable, contexts.remove)
    item.performResetForReuse(renderable)
  }

  /// Runs the item's blocks other than `make`, read from the item.
  private func runBlocksByReadingThem(of item: RenderableItem, with renderable: Renderable, _ contexts: Contexts) {
    item.willInsert?(renderable, contexts.insert)
    item.didInsert?(renderable, contexts.insert)
    item.willUpdate?(renderable, contexts.update)
    item.update(renderable, contexts.update)
    item.willRemove?(renderable, contexts.remove)
    item.didRemove?(renderable, contexts.remove)
    item.resetForReuse?(renderable)
  }

  /// An item whose own update block appends "own" to the layer's name.
  private func makeItem() -> RenderableItem {
    RenderableItem(
      id: .custom("item"),
      frame: .zero,
      make: { _ in .layer(CALayer()) },
      update: appendingToken("own")
    )
  }

  private func keyedUpdate(_ key: RenderableUpdateKey?, _ block: @escaping (Renderable, RenderableUpdateContext) -> Void) -> RenderableItem.AdditionalUpdate {
    RenderableItem.AdditionalUpdate(key: key, block: block)
  }

  private func updateList(_ updates: RenderableItem.AdditionalUpdate...) -> RenderableItem.AdditionalUpdates {
    updates.reduce(.none) { $0.adding($1) }
  }

  /// An update block that appends a token to the layer's name, so the order the blocks ran in shows on the layer.
  private func appendingToken(_ token: String) -> (Renderable, RenderableUpdateContext) -> Void {
    { renderable, _ in
      let layer = renderable.layer
      layer.name = layer.name.map { "\($0),\(token)" } ?? token
    }
  }

  /// Updates a fresh layer with the item, through `performUpdate` as the render pass does or through the `update` block.
  private func appliedTokens(of item: RenderableItem, byReadingTheBlock: Bool = false) -> [String] {
    let layer = CALayer()
    withUpdateContext { context in
      if byReadingTheBlock {
        item.update(.layer(layer), context)
      } else {
        item.performUpdate(.layer(layer), context)
      }
    }
    return layer.name?.components(separatedBy: ",") ?? []
  }

  private func withUpdateContext(_ body: (RenderableUpdateContext) -> Void) {
    withContexts { body($0.update) }
  }

  /// The contexts of the render pass's calls to an item's blocks.
  private struct Contexts {
    let make: RenderableMakeContext
    let insert: RenderableInsertContext
    let update: RenderableUpdateContext
    let remove: RenderableRemoveContext
  }

  private func withContexts(_ body: (Contexts) -> Void) {
    // the contexts hold the content view weakly, so the view is kept alive through the body
    let contentView = ComposeView()
    withExtendedLifetime(contentView) {
      body(Contexts(
        make: RenderableMakeContext(initialFrame: nil, contentView: contentView),
        insert: RenderableInsertContext(oldFrame: .zero, newFrame: .zero, contentView: contentView),
        update: RenderableUpdateContext(
          updateType: .refresh,
          oldFrame: .zero,
          newFrame: .zero,
          previousRenderBounds: .zero,
          renderBounds: .zero,
          animationTiming: nil,
          contentView: contentView,
          contentEvaluation: nil,
          animationDecision: ComposeView.AnimationDecision.disabled
        ),
        remove: RenderableRemoveContext(oldFrame: .zero, contentView: contentView)
      ))
    }
  }
}
