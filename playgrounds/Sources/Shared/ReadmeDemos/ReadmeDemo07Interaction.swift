//
//  ReadmeDemo07Interaction.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/18/26.
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

import ComposeUI

/// The README "Interaction" demo: a button with normal, hovered and pressed content.
final class InteractionDemoView: ComposeView {

  var joined = false

  @ComposeContentBuilder
  override var content: ComposeContent {
    let joined = self.joined
    ButtonNode(
      content: { state in
        ColorNode(joined ? .systemGray : .systemBlue)
          .cornerRadius(20)
          .opacity(
            state == .pressed ? 0.6 : (state == .hovered ? 0.8 : 1)
          )
          .overlay {
            Label(joined ? "Joined" : "Join")
              .textColor(.white)
          }
          .frame(width: 120, height: 40)
      },
      onTap: { [weak self] in
        self?.joined.toggle()
        self?.refresh()
      }
    )
  }
}
