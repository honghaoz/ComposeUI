//
//  SwiftUIRendererView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/15/21.
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

import SwiftUI

#if canImport(AppKit)

import AppKit

/// A view that renders a SwiftUI view.
public final class SwiftUIRendererView<ContentView: SwiftUI.View>: NSHostingView<AnyView> {

  public required init(rootView: ContentView) {
    super.init(rootView: Self.makeWrappedRootView(rootView: rootView))

    updateCommonSettings()
  }

  @available(*, unavailable)
  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  @available(*, unavailable)
  public required init(rootView: AnyView) {
    fatalError("init(rootView:) is unavailable") // swiftlint:disable:this fatal_error
  }

  /// Whether the view is user interactive.
  public var isUserInteractionEnabled: Bool = true

  override public func becomeFirstResponder() -> Bool {
    if isUserInteractionEnabled == false {
      return false
    } else {
      return super.becomeFirstResponder()
    }
  }

  private static func makeWrappedRootView(rootView: ContentView) -> AnyView {
    if #available(macOS 11.0, *) {
      return SwiftUI.ZStack {
        SwiftUI.Color.clear
        rootView
          .ignoresSafeArea(.all, edges: .all)
          .ignoresSafeArea(.container, edges: .all)
          .ignoresSafeArea(.keyboard, edges: .all)
      }
      .ignoresSafeArea(.all, edges: .all)
      .ignoresSafeArea(.container, edges: .all)
      .ignoresSafeArea(.keyboard, edges: .all)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .eraseToAnyView()
    } else {
      return SwiftUI.ZStack {
        SwiftUI.Color.clear
        rootView
          .edgesIgnoringSafeArea(.all)
      }
      .edgesIgnoringSafeArea(.all)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .eraseToAnyView()
    }
  }
}

#endif

#if canImport(UIKit)

import UIKit

/// A view that renders a SwiftUI view.
public final class SwiftUIRendererView<ContentView: SwiftUI.View>: UIView {

  private let hostingController: SwiftUIRendererViewController<ContentView>

  public init(rootView: ContentView) {
    self.hostingController = SwiftUIRendererViewController(rootView: rootView)

    super.init(frame: .zero)

    addSubview(hostingController.view)
  }

  @available(*, unavailable)
  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override public func layoutSubviews() {
    super.layoutSubviews()

    hostingController.view.frame = bounds
  }
}

/// This hosting view controller converts a SwiftUI view to UIView
private final class SwiftUIRendererViewController<ContentView: SwiftUI.View>: UIHostingController<AnyView> {

  init(rootView: ContentView) {
    super.init(rootView: Self.makeWrappedRootView(rootView: rootView))

    // SwiftUI view jumps when scrolling to edges, fix it by disabling safe area.
    disableSafeArea()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .clear
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  private static func makeWrappedRootView(rootView: ContentView) -> AnyView {
    if #available(iOS 14.0, *) {
      return SwiftUI.ZStack {
        SwiftUI.Color.clear
        rootView
          .ignoresSafeArea(.all, edges: .all)
          .ignoresSafeArea(.container, edges: .all)
          .ignoresSafeArea(.keyboard, edges: .all)
      }
      .ignoresSafeArea(.all, edges: .all)
      .ignoresSafeArea(.container, edges: .all)
      .ignoresSafeArea(.keyboard, edges: .all)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .eraseToAnyView()
    } else {
      return SwiftUI.ZStack {
        SwiftUI.Color.clear
        rootView
          .edgesIgnoringSafeArea(.all)
      }
      .edgesIgnoringSafeArea(.all)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .eraseToAnyView()
    }
  }

  private func disableSafeArea() {
    guard let originalClass = object_getClass(view) else {
      return
    }

    let subclassClassName = String(cString: class_getName(originalClass)).appending("_IgnoreSafeArea")
    if let subclass = NSClassFromString(subclassClassName) {
      object_setClass(view, subclass)
    } else {
      // make a new dynamic subclass
      guard let subclassClassNameUtf8 = (subclassClassName as NSString).utf8String else {
        return
      }
      guard let subclass = objc_allocateClassPair(originalClass, subclassClassNameUtf8, 0) else {
        return
      }

      if let method = class_getInstanceMethod(UIView.self, #selector(getter: UIView.safeAreaInsets)) {
        let block: @convention(block) (AnyObject) -> UIEdgeInsets = { _ in
          .zero
        }
        class_addMethod(
          subclass,
          #selector(getter: UIView.safeAreaInsets),
          imp_implementationWithBlock(block),
          method_getTypeEncoding(method)
        )
      } else {
        assertionFailure("no UIView.safeAreaInsets")
      }

      objc_registerClassPair(subclass)
      object_setClass(view, subclass)
    }
  }
}

#endif

private extension SwiftUI.View {

  func eraseToAnyView() -> AnyView {
    AnyView(self)
  }
}
