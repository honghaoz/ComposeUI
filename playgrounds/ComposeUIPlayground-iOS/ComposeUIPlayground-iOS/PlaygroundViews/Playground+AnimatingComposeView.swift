//
//  Playground+AnimatingComposeView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/23/24.
//

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ComposeUI

extension Playground {

  class AnimatingComposeView: ComposeView {

    #if canImport(AppKit)
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()

      if window != nil {
        startAnimation()
      }
    }
    #endif

    #if canImport(UIKit)
    override func didMoveToWindow() {
      super.didMoveToWindow()

      if window != nil {
        startAnimation()
      }
    }
    #endif

    private var isAnimating = false
    private func startAnimation() {
      guard !isAnimating else {
        return
      }

      isAnimating = true

      let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        self?.animate()
      }
      RunLoop.main.add(timer, forMode: .common)
    }

    func animate() {}
  }
}
