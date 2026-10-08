//
//  MemoryWarning.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/8/26.
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

import Foundation

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Runs the handlers added to it when the system is low on memory, so that the caches the framework keeps across
/// refreshes can empty themselves.
///
/// It's used on the main thread.
enum MemoryWarning {

  /// The handlers to run when the system is low on memory.
  private static var handlers: [() -> Void] = []

  #if canImport(AppKit)
  /// The source of the system's memory pressure events.
  private(set) static var memoryPressureSource: DispatchSourceMemoryPressure?
  #endif

  /// Adds a handler to run on the main thread each time the system is low on memory.
  ///
  /// - Parameter handler: The handler to run.
  static func addHandler(_ handler: @escaping () -> Void) {
    // the system's signals are listened to from the first handler on, so a process that keeps no cache doesn't listen
    if handlers.isEmpty {
      startListening()
    }
    handlers.append(handler)
  }

  /// Runs the handlers, as the system's low memory signals do.
  static func handleMemoryWarning() {
    for handler in handlers {
      handler()
    }
  }

  /// Starts listening to the system's low memory signals.
  private static func startListening() {
    #if canImport(AppKit)
    let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
    source.setEventHandler(handler: handleMemoryWarning)
    source.activate()
    memoryPressureSource = source
    #endif

    #if canImport(UIKit)
    NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
      handleMemoryWarning()
    }
    #endif
  }
}
