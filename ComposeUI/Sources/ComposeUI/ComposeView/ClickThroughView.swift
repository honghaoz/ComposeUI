//
//  ClickThroughView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/26.
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

/// A view that passes every click to the views behind it: its `hitTest(_:)` returns `nil` for every point.
///
/// AppKit hit-tests a view's subviews in their order, so a render pass keeps the views of the items in the items order
/// for clicks, see `ComposeView.ZOrderPass`. A view that passes every click through can be anywhere in the subview
/// order, so the render pass leaves it where it is, and keeps it hidden in place while no item takes it, see
/// `ComposeView.InPlaceReuse`, since each change of the subview order makes AppKit build the layer tree of the window's
/// views again at the next display.
protocol ClickThroughView: NSView {}
#endif
