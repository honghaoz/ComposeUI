//
//  RotationView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
//

import ComposeUI
import AppKit

/// A view that rotates its content view.
final class RotationView: BaseView {

    /// The degrees to rotate the content view.
    var degrees: CGFloat = 0 {
        didSet {
            containerLayer.transform = CATransform3DMakeRotation(degrees * .pi / 180, 0, 0, 1)
        }
    }

    let content: Renderable
    private let contentLayer: CALayer

    private lazy var containerLayer: CALayer = {
        let layer = CALayer()
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return layer
    }()

    /// Creates a new `RotationView` with the given content view.
    ///
    /// - Parameter contentView: The content view to rotate.
    init(contentView: View) {
        self.content = .view(contentView)

        if let layer = contentView.layer {
            self.contentLayer = layer
        } else {
            assertionFailure("contentView.layer is nil")
            self.contentLayer = CALayer()
        }

        super.init(frame: .zero)

        commonInit()
    }

    init(contentLayer: CALayer) {
        self.content = .layer(contentLayer)
        self.contentLayer = contentLayer

        super.init(frame: .zero)

        commonInit()
    }

    private func commonInit() {
        containerLayer.frame = bounds
        layer?.addSublayer(containerLayer)

        contentLayer.frame = containerLayer.bounds
        containerLayer.addSublayer(contentLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        containerLayer.disableActions(for: ["transform", "position", "bounds"]) {
            let originalTransform = containerLayer.transform

            containerLayer.transform = CATransform3DIdentity
            containerLayer.frame = bounds

            containerLayer.transform = originalTransform
        }

        contentLayer.disableActions(for: ["position", "bounds"]) {
            contentLayer.frame = containerLayer.bounds
        }
    }
}
