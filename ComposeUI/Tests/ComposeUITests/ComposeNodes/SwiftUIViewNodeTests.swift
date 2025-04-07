//
//  SwiftUIViewNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/6/25.
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
import SwiftUI

class SwiftUIViewNodeTests: XCTestCase {

  func test() {
    var view1: SwiftUIHostingView<AnyView>?
    var view2: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      SwiftUIViewNode(Text("Hello, World!"))
        .onInsert { renderable, _ in
          view1 = renderable.view as? SwiftUIHostingView<AnyView>
        }

      SwiftUIViewNode {
        Text("Hello, World!")
      }
      .onInsert { renderable, _ in
        view2 = renderable.view as? MutableSwiftUIHostingView
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    contentView.refresh()

    expect(view1?.bounds.size) == CGSize(width: 100, height: 25)
    expect(view1?.isUserInteractionEnabled) == true
    expect(view2?.bounds.size) == CGSize(width: 100, height: 25)
    expect(view2?.isUserInteractionEnabled) == true
  }
}
