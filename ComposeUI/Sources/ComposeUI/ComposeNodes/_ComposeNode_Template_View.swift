//
//  _ComposeNode_Template_View.swift
//  ComposéUI
//
//  Created by Honghao on 5/11/25.
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

/// A template for creating a ComposeNode that wraps a View.

/**

 #if canImport(AppKit)
 import AppKit
 #endif

 #if canImport(UIKit)
 import UIKit
 #endif

 import ComposeUI

 /// A node that <#...#>
 ///
 /// The node has a flexible size.
 public struct <#MyNode#>: ComposeNode {

   private let state: <#MyView#>.State

   public init(<#foo: String#>) {
     self.state = <#MyView#>.State(foo: foo)
   }

   // MARK: - ComposeNode

   public var id: ComposeNodeId = .custom("io.chouti.ui.<#MyNode#>")

   public var size: CGSize = .zero

   public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
     size = containerSize
     return ComposeNodeSizing(width: .flexible, height: .flexible)
   }

   public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
     let frame = CGRect(origin: .zero, size: size)
     guard visibleBounds.intersects(frame) else {
       return []
     }

     let viewItem = ViewItem<<#MyView#>>(
       id: id,
       frame: frame,
       make: { <#MyView#>(frame: $0.initialFrame ?? .zero) },
       update: { view, context in
         guard context.updateType.requiresFullUpdate else {
           return
         }
         view.update(state: state, context: context)
       }
     )

     return [viewItem.eraseToRenderableItem()]
   }
 }

 // MARK: - <#MyView#>

 private class <#MyView#>: BaseView {

   struct State {
     var <#foo: String#>
   }

   private var state: State?

   override init(frame: CGRect) {
     super.init(frame: frame)
   }

   func update(state: State, context: RenderableUpdateContext) {
     self.state = state

     // ...
   }
 }

  */
