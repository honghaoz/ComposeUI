//
//  UIView+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/27/24.
//

import UIKit

extension UIView {

    var windowScaleFactor: CGFloat {
        if let window {
            return window.screen.scale
        } else {
            return UIScreen.main.scale
        }
    }

    /// Returns the intrinsic size of the view with the given container size.
    ///
    /// - Parameters:
    ///   - proposedSize: The proposed container size.
    /// - Returns: The intrinsic size of the view.
    func intrinsicSize(for proposedSize: CGSize) -> CGSize {
        if usesConstraintBasedLayout {
            return systemLayoutSizeFitting(proposedSize)
        } else {
            return sizeThatFits(proposedSize)
        }
    }

    /// Returns true if the view is using constraint-based layout.
    private var usesConstraintBasedLayout: Bool {
        Self.requiresConstraintBasedLayout || !translatesAutoresizingMaskIntoConstraints || !constraints.isEmpty
    }
}
