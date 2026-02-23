//
//  UIView+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/27/24.
//

import UIKit

extension UIView {

  var windowScaleFactor: CGFloat {
    if let window {
      return window.screen.scale
    } else {
      return UIScreen.main.scale
    }
  }
}
