//
//  Playground+ScrollView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/22/25.
//

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ComposeUI

extension Playground {

  final class ScrollView: AnimatingComposeView {

    override var content: ComposeContent {
      HStack {
        VStack {
          for color in [
            Colors.RetroApple.green,
            Colors.RetroApple.yellow,
            Colors.RetroApple.orange,
            Colors.RetroApple.red,
            Colors.RetroApple.purple,
          ] {
            ColorNode(color)
              .frame(width: 200, height: 50)
          }
        }

        VStack {
          for color in [
            Colors.RetroApple.purple,
            Colors.RetroApple.red,
            Colors.RetroApple.orange,
            Colors.RetroApple.yellow,
            Colors.RetroApple.green,
          ] {
            ColorNode(color)
              .frame(width: 200, height: 50)
          }
        }
      }
    }

    override init(frame: CGRect) {
      super.init(frame: frame)

      scrollBehavior = .auto
    }
  }
}
