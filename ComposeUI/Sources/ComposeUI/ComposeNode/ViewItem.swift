//
//  ViewItem.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
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

import UIKit

public struct ViewItem<T: UIView> {

  let id: String

  let frame: CGRect

  let make: () -> T

  // TODO: pass in update type: bounds change, scroll, refresh
  let update: (T) -> Void

  public init(id: String,
              frame: CGRect,
              make: @escaping () -> T = { T() },
              update: @escaping (T) -> Void)
  {
    self.id = id
    self.frame = frame
    self.make = make
    self.update = update
  }

  func id(_ id: String) -> Self {
    Self(id: id, frame: frame, make: make, update: update)
  }

  func frame(_ frame: CGRect) -> Self {
    Self(id: id, frame: frame, make: make, update: update)
  }

  func update(_ update: @escaping (T) -> Void) -> Self {
    Self(id: id, frame: frame, make: make, update: update)
  }

  func addsUpdate(_ additionalUpdate: @escaping (T) -> Void) -> Self {
    Self(id: id, frame: frame, make: make, update: { view in
      update(view)
      additionalUpdate(view)
    })
  }

  func eraseToUIViewItem() -> ViewItem<UIView> {
    ViewItem<UIView>(
      id: id,
      frame: frame,
      make: make,
      update: { update($0 as! T) } // swiftlint:disable:this force_cast
    )
  }
}
