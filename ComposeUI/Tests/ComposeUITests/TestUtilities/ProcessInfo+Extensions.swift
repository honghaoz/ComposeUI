//
//  ProcessInfo+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/24/25.
//

import Foundation

extension ProcessInfo {

    static var isRunningInGitHubActions: Bool {
        ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
    }
}
