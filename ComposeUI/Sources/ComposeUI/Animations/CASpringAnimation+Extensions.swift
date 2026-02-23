//
//  CASpringAnimation+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/23/24.
//

import QuartzCore

extension CASpringAnimation {

    /// Get the perceptual duration.
    public func perceptualDuration() -> TimeInterval {
        duration(epsilon: 0.005) ?? {
            if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *) {
                return perceptualDuration
            } else {
                return settlingDuration
            }
        }()
    }

    /// `durationForEpsilon:`
    private static let durationForEpsilonSelector = Selector(String("l}zi|qwvNwzMx{qtwvB".map { Character(UnicodeScalar($0.asciiValue! - 8)) })) // swiftlint:disable:this force_unwrapping

    private func duration(epsilon: Double) -> TimeInterval? {
        let selector = Self.durationForEpsilonSelector
        guard self.responds(to: selector) else {
            return nil
        }

        typealias Method = @convention(c) (AnyObject, Selector, Double) -> Double
        let methodIMP = method(for: selector)
        let method: Method = unsafeBitCast(methodIMP, to: Method.self)
        let duration = method(self, selector, epsilon)

        return duration
    }
}
