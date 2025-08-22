//
//  _ComposeNode_Template_Layer.swift
//  ComposéUI
//
//  Created by Honghao on 5/12/25.
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

/// A template for creating a ComposeNode that wraps a Layer.

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

   private let state: <#MyLayer#>.State

   public init(<#foo: String#>) {
     self.state = <#MyLayer#>.State(foo: foo)
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

     let layerItem = LayerItem<<#MyLayer#>>(
       id: id,
       frame: frame,
       make: { _ in <#MyLayer#>() },
       update: { layer, context in
         // NOTE: if the content update depends on the layer's bounds, should switch context.updateType explicitly (for .boundsChange)
         guard context.updateType.requiresFullUpdate else {
           return
         }
         layer.update(state: state, context: context)
       }
     )

     return [layerItem.eraseToRenderableItem()]
   }
 }

 // MARK: - <#MyLayer#>

 private class <#MyLayer#>: CALayer {

   struct State {
     var <#foo: String#>
   }

   private var state: State?

   override init() {
     super.init()

     // ...
   }

   @available(*, unavailable)
   required init?(coder: NSCoder) {
     fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
   }

   override init(layer: Any) {
     guard let layer = layer as? Self else {
       // swiftlint:disable:next fatal_error
       fatalError("expect the `layer` to be the same type during an animation.")
     }
     super.init(layer: layer)
   }

   func update(state: State, context: RenderableUpdateContext) {
     self.state = state

     // ...
   }
 }

 */
