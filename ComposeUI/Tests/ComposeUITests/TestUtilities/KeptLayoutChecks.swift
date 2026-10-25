//
//  KeptLayoutChecks.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/24/26.
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

@testable import ComposeUI

#if COMPOSEUI_SANITY_CHECKS
/// The debug check of the layouts that `ComposeView` and stacks keep at another container size, which only the builds
/// that run the sanity checks have.
enum KeptLayoutChecks {

  /// Whether a kept layout is checked against a new layout at the other container size, which lays the content out
  /// again, so a test that counts the layouts that a kept layout saves turns it off, and back on when it finishes.
  static var isOn: Bool {
    get {
      ComposeNodeSizing.Dependence.checksKeptLayouts
    }
    set {
      ComposeNodeSizing.Dependence.checksKeptLayouts = newValue
    }
  }
}
#endif
