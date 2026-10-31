//
//  HostWindow.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/30/26.
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

import ChouTiTest
import UIKit

/// A visible window in the host app's window scene.
///
/// UIKit sets up a view in a window scene as in an app, which it doesn't do in a window without a scene, such as visionOS
/// wrapping the layers of some views.
final class HostWindow: UIWindow {

  /// The view to add views to, which fills the window.
  let contentView: UIView

  /// Makes a window in a window scene.
  ///
  /// - Parameter windowScene: The window scene to show the window in.
  init(scene windowScene: UIWindowScene) {
    let rootViewController = UIViewController()
    contentView = rootViewController.view

    super.init(windowScene: windowScene)

    self.rootViewController = rootViewController
    isHidden = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  #if os(visionOS)

  /// Waits until the window wraps the layers of the views that join it, as an app's window does when it shows its
  /// content, which visionOS starts a few run loop turns after the window shows.
  fileprivate func waitUntilWrappingLayers(file: StaticString, line: UInt) throws {
    let label = UILabel()
    contentView.addSubview(label)
    defer {
      label.removeFromSuperview()
    }
    let deadline = Date(timeIntervalSinceNow: Constants.wrappingTimeout)
    while label.layer.superlayer === contentView.layer, Date() < deadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: Constants.pollInterval))
    }
    guard label.layer.superlayer !== contentView.layer else {
      fail("the window doesn't wrap the layer of a label", file: file, line: line)
      throw WrappingTimeoutError()
    }
  }

  private struct WrappingTimeoutError: Error {}

  #endif

  /// The host app's window scene, waiting for it to connect, which it can do after the tests start.
  static func hostScene() -> UIWindowScene? {
    let deadline = Date(timeIntervalSinceNow: Constants.sceneConnectionTimeout)
    var windowScene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
    while windowScene == nil, Date() < deadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: Constants.pollInterval))
      windowScene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
    }
    return windowScene
  }

  // MARK: - Constants

  private enum Constants {

    /// How long to wait for the host app's window scene to connect.
    static let sceneConnectionTimeout: TimeInterval = 10

    /// How long to wait for a window to wrap the layers of its views.
    static let wrappingTimeout: TimeInterval = 5

    /// How long each run loop turn of a wait runs for.
    static let pollInterval: TimeInterval = 0.005
  }
}

extension XCTestCase {

  /// Makes a window in the host app's window scene, which hides when the test ends.
  ///
  /// - Returns: The window.
  func makeHostWindow(file: StaticString = #filePath, line: UInt = #line) throws -> HostWindow {
    let windowScene = try unwrap(HostWindow.hostScene(), "the host app's window scene", file: file, line: line)
    let window = HostWindow(scene: windowScene)
    // a visible window stays in its scene until it hides
    addTeardownBlock {
      window.isHidden = true
    }
    #if os(visionOS)
    try window.waitUntilWrappingLayers(file: file, line: line)
    #endif
    return window
  }
}
