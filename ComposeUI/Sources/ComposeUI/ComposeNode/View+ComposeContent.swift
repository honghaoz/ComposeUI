//
//  View+ComposeContent.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

extension UIView: ComposeContent {

  public func asNodes() -> [any ComposeNode] {
    [ViewNode(self)]
  }
}
