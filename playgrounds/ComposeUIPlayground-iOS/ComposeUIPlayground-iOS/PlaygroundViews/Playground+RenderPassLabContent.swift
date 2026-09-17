//
//  Playground+RenderPassLabContent.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/17/26.
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

import SwiftUI

import ComposeUI

extension Playground.RenderPassLab {

  /// What the container renders. Each preset exposes a different render path.
  enum Preset: CaseIterable {

    /// Color rows with an update animation and an insert transition, rendered by the container itself.
    case colorRows

    /// The rows inside a nested `ComposeView` rendered by `ComposeViewNode`, filling the container.
    case nestedComposeView

    /// A SwiftUI text whose content is evaluated once per refresh.
    case swiftUI

    /// The rows inside a nested `ComposeView` hosted by a `ViewNode`, filling the container.
    case hostedComposeView

    /// All of the above stacked, taller than the container, so it scrolls.
    case mixed

    var title: String {
      switch self {
      case .colorRows:
        return "color rows"
      case .nestedComposeView:
        return "nested view"
      case .swiftUI:
        return "SwiftUI"
      case .hostedComposeView:
        return "hosted view"
      case .mixed:
        return "mixed"
      }
    }

    /// The next preset in the cycle.
    var next: Preset {
      let presets = Self.allCases
      // swiftlint:disable:next force_unwrapping
      let index = presets.firstIndex(of: self)!
      return presets[(index + 1) % presets.count]
    }
  }

  /// A `ComposeView.AnimationBehavior` the lab can cycle through and name.
  enum Behavior: CaseIterable {

    case `default`
    case disabled

    /// `.dynamic` deciding to animate every pass, including bounds changes.
    case dynamic

    var title: String {
      switch self {
      case .default:
        return "default"
      case .disabled:
        return "disabled"
      case .dynamic:
        return "dynamic"
      }
    }

    var animationBehavior: ComposeView.AnimationBehavior {
      switch self {
      case .default:
        return .default
      case .disabled:
        return .disabled
      case .dynamic:
        return .dynamic { _, _ in true }
      }
    }

    /// The next behavior in the cycle.
    var next: Behavior {
      let behaviors = Self.allCases
      // swiftlint:disable:next force_unwrapping
      let index = behaviors.firstIndex(of: self)!
      return behaviors[(index + 1) % behaviors.count]
    }
  }

  /// The last update a marker row received, for showing whether reused renderables animated.
  struct RowUpdate {

    /// The kind of update, in the words the pass descriptions use: `insert`, `refresh`, `resize`, `scroll`.
    let kind: String

    /// Whether the update applied an animation timing.
    let isAnimated: Bool

    /// The update described like a pass, for example `refresh (animated)` or `resize (instant)`.
    var description: String {
      "\(kind) (\(isAnimated ? "animated" : "instant"))"
    }

    init(_ context: RenderableUpdateContext) {
      switch context.updateType {
      case .insert:
        kind = "insert"
      case .refresh:
        kind = "refresh"
      case .boundsChange:
        if context.previousRenderBounds?.size != context.renderBounds.size {
          kind = "resize"
        } else {
          kind = "scroll"
        }
      }
      isAnimated = context.animationTiming != nil
    }
  }

  /// The data the container's content is built from. Changed by the lab's controls, read on refresh.
  final class Model {

    var preset: Preset = .colorRows
    var containerBehavior: Behavior = .default
    var nestedBehavior: Behavior = .default

    /// The row colors, randomized by "Mutate data".
    var rowColors: [ComposeUI.Color] = Colors.RetroApple.all

    /// Whether an extra row is in the content, toggled by "Mutate data" so refreshes run transitions.
    var showsExtraRow = false

    /// A counter shown by the SwiftUI preset, bumped by "Mutate data".
    var counter = 0

    /// How many times the container built its content. A refresh builds, a bounds change does not.
    private(set) var buildCount = 0

    /// The last update of the marker row, per view rendering rows.
    var rowUpdates: [String: RowUpdate] = [:]

    /// The nested view rendered by `ComposeViewNode`, captured when the parent inserts it.
    weak var nestedComposeView: ComposeView?

    /// The nested view hosted by `ViewNode`, created once and reused across refreshes.
    lazy var hostedComposeView: ComposeView = ComposeView { [weak self] in
      self?.rows(owner: Owner.hosted) ?? Empty()
    }

    /// Called with the nested view a preset renders, so the lab can wire its handlers and behavior.
    var onNestedViewInserted: ((ComposeView) -> Void)?

    /// Randomizes the data the content is built from. Takes effect on the next refresh.
    func mutate() {
      rowColors = Colors.RetroApple.all.shuffled()
      showsExtraRow.toggle()
      counter += 1
    }

    /// The nested view the "Nested" controls act on for the current preset, if the preset has one.
    var currentNestedView: ComposeView? {
      switch preset {
      case .colorRows,
           .swiftUI:
        return nil
      case .nestedComposeView,
           .mixed:
        return nestedComposeView
      case .hostedComposeView:
        return hostedComposeView
      }
    }

    /// The name of the current preset's nested view, as the key of its recorded passes and row updates.
    var currentNestedOwner: String? {
      switch preset {
      case .colorRows,
           .swiftUI:
        return nil
      case .nestedComposeView,
           .mixed:
        return Owner.nested
      case .hostedComposeView:
        return Owner.hosted
      }
    }

    // MARK: - Content

    /// Builds the container's content for the current preset, counting the build.
    func buildContent() -> ComposeContent {
      buildCount += 1
      // the pass records the container's rows again if the preset has them, so a preset without them shows none
      rowUpdates[Owner.container] = nil
      return content
    }

    @ComposeContentBuilder
    private var content: ComposeContent {
      switch preset {
      case .colorRows:
        rows(owner: Owner.container)
      case .nestedComposeView:
        nestedComposeViewNode(height: .flexible)
      case .swiftUI:
        swiftUIText
      case .hostedComposeView:
        hostedComposeViewNode(height: .flexible)
      case .mixed:
        VStack(spacing: Constants.sectionSpacing) {
          rows(owner: Owner.container)
          nestedComposeViewNode(height: .fixed(nestedHeight))
          swiftUIText
          hostedComposeViewNode(height: .fixed(nestedHeight))
        }
      }
    }

    /// Color rows with an update animation and an insert transition. The first row records its updates.
    ///
    /// - Parameter owner: The name of the view rendering the rows, for the recorded updates.
    @ComposeContentBuilder
    func rows(owner: String) -> ComposeContent {
      VStack(spacing: Constants.rowSpacing) {
        for (index, color) in rowColors.enumerated() {
          ColorNode(color)
            .cornerRadius(Constants.rowCornerRadius)
            .frame(width: .flexible, height: Constants.rowHeight)
            .animation(.spring())
            .transition(.opacity(timing: .linear(duration: 0.5)))
            .onUpdate { [weak self] _, context in
              guard index == 0 else {
                return
              }
              self?.rowUpdates[owner] = RowUpdate(context)
            }
            .id("\(owner)-row-\(index)")
        }
        if showsExtraRow {
          ColorNode(Colors.blueGray)
            .cornerRadius(Constants.rowCornerRadius)
            .frame(width: .flexible, height: Constants.rowHeight)
            .transition(.slide(from: .right))
            .id("\(owner)-extra-row")
        }
      }
      .padding(Constants.contentPadding)
    }

    /// The rows inside a nested view rendered by `ComposeViewNode`. The node animates its frame like the rows do, so the
    /// presets differ by nesting alone: a reused renderable's frame animates only when its node has a timing.
    private func nestedComposeViewNode(height: FrameSize) -> ComposeNode {
      ComposeViewNode { [weak self] in
        self?.rows(owner: Owner.nested) ?? Empty()
      }
      .flexibleSize()
      .frame(width: .flexible, height: height)
      .animation(.spring())
      .id("nested-compose-view")
      .willInsert { [weak self] renderable, _ in
        guard let self, let view = renderable.view as? ComposeView else {
          return
        }
        self.nestedComposeView = view
        self.onNestedViewInserted?(view)
      }
    }

    /// The rows inside a nested view hosted by `ViewNode`.
    private func hostedComposeViewNode(height: FrameSize) -> ComposeNode {
      ViewNode<ComposeView>(hostedComposeView)
        .flexibleSize()
        .frame(width: .flexible, height: height)
        .animation(.spring())
        .id("hosted-compose-view")
    }

    /// A SwiftUI text showing the counter. The closure is evaluated once per refresh, so a resize keeps the text.
    private var swiftUIText: ComposeNode {
      SwiftUIViewNode { [weak self] in
        Text("SwiftUI counter: \(self?.counter ?? 0)")
          .font(.system(size: 15, weight: .medium))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(SwiftUI.Color(Colors.lightBlueGray))
          .clipShape(RoundedRectangle(cornerRadius: Constants.rowCornerRadius))
      }
      .frame(width: .flexible, height: Constants.rowHeight)
      .padding(horizontal: Constants.contentPadding)
      .id("swiftui-text")
    }

    /// The height of the rows plus the padding, for a nested view stacked with other content.
    private var nestedHeight: CGFloat {
      let rowCount = CGFloat(rowColors.count + (showsExtraRow ? 1 : 0))
      return rowCount * Constants.rowHeight + (rowCount - 1) * Constants.rowSpacing + Constants.contentPadding * 2
    }
  }

  /// The names of the views that render rows, as the keys of the recorded passes and row updates.
  enum Owner {

    static let container = "container"
    static let nested = "nested"
    static let hosted = "hosted"
  }
}
