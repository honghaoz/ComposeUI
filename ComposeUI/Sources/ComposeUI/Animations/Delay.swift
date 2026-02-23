//
//  Delay.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/21.
//

import Foundation

/// Delay with strict timing.
///
/// - Parameters:
///   - delay: The delay of the animation.
///   - task: The task to be executed after the delay, on the main thread.
func delay(_ delay: TimeInterval, task: @escaping () -> Void) {
  guard delay > 0 else {
    task()
    return
  }

  let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
  timer.schedule(deadline: .now() + delay, leeway: .nanoseconds(0))
  timer.setEventHandler {
    task()
    timer.cancel()
  }
  timer.resume()
}
