//
//  RunLoop.swift
//  ComposéUI
//
//  Created by Honghao on 5/10/25.
//

import Foundation

/// Schedule a block to be executed on the next main runloop.
///
/// - Parameter block: The block to be executed.
func onNextRunLoop(_ block: @escaping () -> Void) {
    RunLoop.main.perform(inModes: [.common]) {
        block()
    }
}
