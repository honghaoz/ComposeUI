//
//  Thread+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/4/21.
//

#if DEBUG
import Foundation

extension Thread {

    static var isRunningXCTest: Bool {
        Thread.main.threadDictionary.allKeys.contains { key in
            guard let key = key as? String else {
                return false
            }
            return key.range(of: "xctest", options: .caseInsensitive) != nil || key.contains("kXCTContextStackThreadKey")
        }
    }
}
#endif
