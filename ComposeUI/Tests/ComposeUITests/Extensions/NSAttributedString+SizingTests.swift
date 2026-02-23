//
//  NSAttributedString+SizingTests.swift
//  ComposéUI
//
//  Created by Honghao on 6/21/25.
//

import XCTest

@testable import ComposeUI

class NSAttributedString_SizingTests: XCTestCase {

    // MARK: - Singleline

    func test_singleLine_empty() throws {
        let attributedString = NSAttributedString(string: "")
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
        XCTAssertEqual(size, .zero)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byWordWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byCharWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byClipping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byClipping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byWordWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byCharWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byClipping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byClipping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 724.53125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 717.8719999999996, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09, accuracy: 1e-1)
    }

    // MARK: - Multiline

    func test_multiline_empty() throws {
        let attributedString = NSAttributedString(string: "")
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100)
        XCTAssertEqual(size, .zero)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 97.671875, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.18, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byWordWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 97.84, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.18, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 99.34375, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.18, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byCharWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 98.06, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.18, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byClipping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09375, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byClipping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 92.4375, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09375, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 95.744, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 99.703125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09375, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 92.768, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 94.1796875, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09375, accuracy: 1e-1)
    }

    func test_multiline_byWordWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
        XCTAssertEqual(size.width, 96.608, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 99.8203125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 152.75, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byWordWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 98.096, accuracy: 1e-1)
        XCTAssertEqual(size.height, 152.70, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 99.8203125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 152.75, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byCharWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 98.096, accuracy: 1e-1)
        XCTAssertEqual(size.height, 152.70, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byClipping_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09375, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byClipping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 92.4375, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09375, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 95.744, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 99.703125, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09375, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 92.768, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
        let attributedString = try makeAttributedString(font: UIFont.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 94.1796875, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.09375, accuracy: 1e-1)
    }

    func test_multiline_byCharWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
        XCTAssertEqual(size.width, 96.608, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byClipping_paragraphStyle_byWordWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
        XCTAssertEqual(size.width, 100, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.176, accuracy: 1e-1)
    }

    func test_multiline_byClipping_paragraphStyle_byCharWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.176, accuracy: 1e-1)
    }

    func test_multiline_byClipping_paragraphStyle_byClipping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byClipping_paragraphStyle_byTruncatingTail_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
        XCTAssertEqual(size.width, 95.744, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byClipping_paragraphStyle_byTruncatingHead_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
        XCTAssertEqual(size.width, 92.768, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byClipping_paragraphStyle_byTruncatingMiddle_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
        XCTAssertEqual(size.width, 96.608, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingTail_paragraphStyle_byWordWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
        XCTAssertEqual(size.width, 97.84, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.176, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingTail_paragraphStyle_byCharWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
        XCTAssertEqual(size.width, 98.064, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.176, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingTail_paragraphStyle_byClipping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingTail_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
        XCTAssertEqual(size.width, 95.744, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingHead_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
        XCTAssertEqual(size.width, 92.768, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingMiddle_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
        XCTAssertEqual(size.width, 96.608, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingHead_paragraphStyle_byWordWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
        XCTAssertEqual(size.width, 97.84, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.176, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingHead_paragraphStyle_byCharWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
        XCTAssertEqual(size.width, 98.064, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.176, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingHead_paragraphStyle_byClipping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingTail_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
        XCTAssertEqual(size.width, 95.744, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingHead_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
        XCTAssertEqual(size.width, 92.768, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingMiddle_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
        XCTAssertEqual(size.width, 96.608, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingMiddle_paragraphStyle_byWordWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
        XCTAssertEqual(size.width, 98.08, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.176, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingMiddle_paragraphStyle_byCharWrapping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
        XCTAssertEqual(size.width, 98.064, accuracy: 1e-1)
        XCTAssertEqual(size.height, 38.176, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingMiddle_paragraphStyle_byClipping_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
        XCTAssertEqual(size.width, 100.0, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingTail_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
        XCTAssertEqual(size.width, 95.744, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingHead_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
        XCTAssertEqual(size.width, 92.768, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingMiddle_customFont() throws {
        let attributedString = try makeAttributedString(font: XCTUnwrap(UIFont(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
        let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
        XCTAssertEqual(size.width, 96.608, accuracy: 1e-1)
        XCTAssertEqual(size.height, 19.088, accuracy: 1e-1)
    }

    private func makeAttributedString(font: UIFont, lineBreakMode: NSLineBreakMode) throws -> NSAttributedString {
        NSAttributedString(
            string: Constants.string,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .left
                    style.lineBreakMode = lineBreakMode
                    // style.lineSpacing = 50
                    return style
                }(),
            ]
        )
    }

    // MARK: - Constants

    private enum Constants {
        static let string: String = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore."
    }
}
