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

  // MARK: - Helpers

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
    // the context holds the content view weakly, so the view is kept alive through the update
    let contentView = ComposeView()
    withExtendedLifetime(contentView) {
      body(RenderableUpdateContext(
        updateType: .refresh,
        oldFrame: .zero,
        newFrame: .zero,
        previousRenderBounds: .zero,
        renderBounds: .zero,
        animationTiming: nil,
        contentView: contentView,
        contentEvaluation: nil,
        animationDecision: ComposeView.AnimationDecision.disabled
      ))
    }
  }
}
