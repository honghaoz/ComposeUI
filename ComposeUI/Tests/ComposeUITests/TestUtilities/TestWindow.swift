//
//  TestWindow.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/22/26.
//

import UIKit
import QuartzCore

/// A test window that can be used to test window-related functionality.
public final class TestWindow: UIWindow {

    // MARK: - Content View

    public func contentView() -> UIView {
        return _contentView! // swiftlint:disable:this force_unwrapping
    }

    private var _contentView: UIView!

    // MARK: - Init

    public init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Constants.windowWidth, height: Constants.windowHeight))
        _contentView = UIView(frame: self.bounds)
        addSubview(_contentView)
        _contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
    }

    // MARK: - Constants

    private enum Constants {
        static let windowWidth: CGFloat = 500
        static let windowHeight: CGFloat = 500
    }
}
