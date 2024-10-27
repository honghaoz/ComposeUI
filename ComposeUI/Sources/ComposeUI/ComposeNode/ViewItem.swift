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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// A view item that can create a view and update the view.
public struct ViewItem<T: View> {

  /// The unique identifier of the view item.
  let id: String

  /// The frame of the view.
  let frame: CGRect

  /// The block to create the view.
  let make: () -> T

  /// The block to update the view.
  let update: (T) -> Void // TODO: pass in update type: bounds change, scroll, refresh

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

  /// Set a new id for the view item.
  ///
  /// - Parameter id: The new id.
  /// - Returns: The view item with the new id.
  func id(_ id: String) -> Self {
    Self(id: id, frame: frame, make: make, update: update)
  }

  /// Set a new frame for the view item.
  ///
  /// - Parameter frame: The new frame.
  /// - Returns: The view item with the new frame.
  func frame(_ frame: CGRect) -> Self {
    Self(id: id, frame: frame, make: make, update: update)
  }

  /// Set a new update block for the view item.
  ///
  /// - Parameter update: The new update block.
  /// - Returns: The view item with the new update block.
  func update(_ update: @escaping (T) -> Void) -> Self {
    Self(id: id, frame: frame, make: make, update: update)
  }

  /// Add an additional update block to the view item.
  ///
  /// - Parameter additionalUpdate: The additional update block.
  /// - Returns: The view item with the additional update block.
  func addsUpdate(_ additionalUpdate: @escaping (T) -> Void) -> Self {
    Self(id: id, frame: frame, make: make, update: { view in
      update(view)
      additionalUpdate(view)
    })
  }

  /// Erase the view type to a generic `View` item.
  ///
  /// - Returns: The view item with the generic `View` type.
  func eraseToViewItem() -> ViewItem<View> {
    ViewItem<View>(
      id: id,
      frame: frame,
      make: make,
      update: { update($0 as! T) } // swiftlint:disable:this force_cast
    )
  }
}
