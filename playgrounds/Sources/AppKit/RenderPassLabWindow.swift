//
//  RenderPassLabWindow.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/17/26.
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

import AppKit

/// A resizable window for the render pass lab. Resizing the window resizes the container when it follows the host.
final class RenderPassLabWindow: NSWindowController {

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: Constants.initialSize.width, height: Constants.initialSize.height),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Render Pass Lab"
    window.minSize = Constants.minSize
    self.init(window: window)

    let lab = Playground.RenderPassLab(frame: window.contentLayoutRect)
    lab.autoresizingMask = [.width, .height]
    window.contentView = lab
    window.center()
  }

  // MARK: - Constants

  private enum Constants {
    static let initialSize = CGSize(width: 760, height: 800)
    static let minSize = CGSize(width: 560, height: 640)
  }
}
