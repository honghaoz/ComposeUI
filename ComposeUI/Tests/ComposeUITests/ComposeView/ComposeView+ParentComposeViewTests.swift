//
//  ComposeView+ParentComposeViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/15/26.
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

class ComposeView_ParentComposeViewTests: XCTestCase {

  func test_parentComposeView_rootView_isNil() {
    // given: a view on its own and a view inside a plain container
    let root = ComposeView { Empty() }
    let contained = ComposeView { Empty() }
    let container = BaseView()
    container.addSubview(contained)

    // then: neither has a parent
    expect(root.parentComposeView) == nil
    expect(contained.parentComposeView) == nil
  }

  func test_parentComposeView_viewRenderedByAParent_isTheParent() throws {
    // given: a parent rendering a nested view through a compose view node, which renders a further nested view, and
    // another nested view through a view node
    var nestedView: ComposeView?
    var deeplyNestedView: ComposeView?
    let hostedView = ComposeView { Empty() }
    let parent = ComposeView {
      ComposeViewNode {
        ComposeViewNode {
          Empty()
        }
        .frame(width: 20, height: 20)
        .onUpdate { renderable, _ in
          deeplyNestedView = renderable.view as? ComposeView
        }
      }
      .frame(width: 50, height: 50)
      .onUpdate { renderable, _ in
        nestedView = renderable.view as? ComposeView
      }
      ViewNode<ComposeView>(hostedView)
        .frame(width: 50, height: 50)
    }
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the parent renders
    parent.refresh(animated: false)

    // then: each nested view's parent is the view that renders it, whichever node hosts it
    let nested = try unwrap(nestedView)
    let deeplyNested = try unwrap(deeplyNestedView)
    expect(nested.parentComposeView) === parent
    expect(hostedView.parentComposeView) === parent
    expect(deeplyNested.parentComposeView) === nested
    expect(parent.parentComposeView) == nil

    // then: the lookup relies on the rendered view sitting directly in the parent's content view. the explicit type
    // picks ComposeUI's `contentView()` over AppKit's `NSScrollView.contentView`, the clip view.
    let contentView: View = parent.contentView()
    expect(nested.superview) === contentView
    #if canImport(AppKit)
    // AppKit: the content view is the document view, inside the parent's clip view, inside the parent
    expect(contentView) === parent.documentView
    expect(nested.superview?.superview) === parent.contentView
    expect(nested.superview?.superview?.superview) === parent
    #else
    // UIKit: the content view is the parent itself
    expect(contentView) === parent
    #endif
  }

  func test_parentComposeView_viewAddedToTheContentView_isTheParent() {
    // given: a view added to a parent's content view directly, where the parent's render pass would add it
    let parent = ComposeView { Empty() }
    let child = ComposeView { Empty() }

    // when: the view is added
    let contentView: View = parent.contentView()
    contentView.addSubview(child)

    // then: the parent is found
    expect(child.superview) === contentView
    expect(child.parentComposeView) === parent
  }

  func test_parentComposeView_viewInsideAHostedContainer_isNil() {
    // given: a parent rendering a plain container view that contains a nested view
    let container = BaseView()
    let child = ComposeView { Empty() }
    container.addSubview(child)
    let parent = ComposeView {
      ViewNode<BaseView>(container)
        .frame(width: 50, height: 50)
    }
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the parent renders
    parent.refresh(animated: false)

    // then: the container lays the nested view out, not the parent's pass, so the nested view has no parent
    let contentView: View = parent.contentView()
    expect(container.superview) === contentView
    expect(child.parentComposeView) == nil
  }

  func test_parentComposeView_viewInsideAnOverlayOnTheParent_isNil() {
    // given: a view inside a container inside an overlay added to a parent as a plain subview, bypassing the content view
    let parent = ComposeView { Empty() }
    let overlay = BaseView()
    let container = BaseView()
    let child = ComposeView { Empty() }
    parent.addSubview(overlay)
    overlay.addSubview(container)
    container.addSubview(child)

    // then: the view sits three levels below the parent like a rendered view does on AppKit, but outside the content
    // view, so it has no parent
    expect(child.superview?.superview?.superview) === parent
    expect(child.parentComposeView) == nil
  }

  func test_parentComposeView_subviewOfTheParentItself_dependsOnWhereTheContentViewIs() {
    // given: a view added to a parent as a plain subview, bypassing the content view
    let parent = ComposeView { Empty() }
    let child = ComposeView { Empty() }

    // when: the view is added
    parent.addSubview(child)

    // then: on AppKit the view sits beside the clip view, outside the content view, so it has no parent. on UIKit the
    // parent is its own content view, so the view is in the rendered position and the parent is found.
    #if canImport(AppKit)
    expect(child.parentComposeView) == nil
    #else
    expect(child.parentComposeView) === parent
    #endif
  }
}
