//
//  ComposeContentBuilder+GenericNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/20/26.
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

import QuartzCore
import SwiftUI

import ChouTiTest

@testable import ComposeUI

class ComposeContentBuilder_GenericNodeTests: XCTestCase {

  func test_forLoopOfGenericNodesOfAnOpaqueArgument_buildsEachIteration() {
    // when: building loops whose body is a generic node whose argument is an opaque type that a function returns,
    // which makes the node's type opaque too, so the loop can't collect the nodes in a typed array
    let swiftUIContent: ComposeContent = ComposeUI.VStack {
      for index in 0 ..< 3 {
        SwiftUIViewNode { Self.swiftUIRow(index) }
      }
    }
    let layerContent: ComposeContent = ComposeUI.VStack {
      for _ in 0 ..< 3 {
        Self.layerNode()
      }
    }
    let viewContent: ComposeContent = ComposeUI.VStack {
      for _ in 0 ..< 3 {
        Self.viewNode()
      }
    }

    // then: each loop builds a stack of a node for each iteration
    for content in [swiftUIContent, layerContent, viewContent] {
      expect((content as? VerticalStackNode)?.childNodes.count) == 3
    }
  }

  // MARK: - Helpers

  /// Returns a SwiftUI view of an opaque type.
  private static func swiftUIRow(_ index: Int) -> some SwiftUI.View {
    SwiftUI.Text("Row \(index)")
  }

  /// Returns a layer node whose layer is of an opaque type.
  private static func layerNode() -> LayerNode<some CALayer> {
    LayerNode(CALayer())
  }

  /// Returns a view node whose view is of an opaque type.
  private static func viewNode() -> ViewNode<some ComposeUI.View> {
    ViewNode(ComposeUI.View())
  }
}
