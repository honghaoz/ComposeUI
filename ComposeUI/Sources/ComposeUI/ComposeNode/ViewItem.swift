//
//  ViewItem.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
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
