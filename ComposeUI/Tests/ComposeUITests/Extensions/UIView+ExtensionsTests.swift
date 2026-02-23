//
//  UIView+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/22/26.
//

import UIKit
import XCTest

@testable import ComposeUI

class UIView_ExtensionsTests: XCTestCase {

    func test_intrinsicSize_usesSizeThatFits() {
        let view = IntrinsicSizeView(
            sizeThatFitsValue: CGSize(width: 11, height: 22),
            systemLayoutSizeValue: CGSize(width: 33, height: 44)
        )
        view.translatesAutoresizingMaskIntoConstraints = true

        let size = view.intrinsicSize(for: CGSize(width: 100, height: 200))
        XCTAssertEqual(size, CGSize(width: 11, height: 22))
    }

    func test_intrinsicSize_usesSystemLayoutSizeFitting() {
        let view = IntrinsicSizeView(
            sizeThatFitsValue: CGSize(width: 11, height: 22),
            systemLayoutSizeValue: CGSize(width: 33, height: 44)
        )
        view.translatesAutoresizingMaskIntoConstraints = false

        let size = view.intrinsicSize(for: CGSize(width: 100, height: 200))
        XCTAssertEqual(size, CGSize(width: 33, height: 44))
    }
}

private final class IntrinsicSizeView: UIView {

    private let sizeThatFitsValue: CGSize
    private let systemLayoutSizeValue: CGSize

    init(sizeThatFitsValue: CGSize, systemLayoutSizeValue: CGSize) {
        self.sizeThatFitsValue = sizeThatFitsValue
        self.systemLayoutSizeValue = systemLayoutSizeValue
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented") // swiftlint:disable:this fatal_error
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        sizeThatFitsValue
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        systemLayoutSizeValue
    }
}
