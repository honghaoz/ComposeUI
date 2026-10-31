//
//  ViewLayerWrappingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/30/26.
//  Copyright © 2024 Honghao Zhang.
//
//  MIT License
//
//  Copyright (c) 2024 Honghao Zhang (github.com/honghaoz)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import ChouTiTest
import UIKit

@testable import ComposeUI

/// Pins where UIKit puts the layers of views in a window scene, which ComposeUI's frame code depends on.
class ViewLayerWrappingTests: XCTestCase {

  func test_wrapsTheLayersOfSomeViews() throws {
    // given: views of the kinds that apps show, and of ComposeUI's own kinds
    let window = try makeHostWindow()
    let views: [(view: UIView, isWrappedOnVisionOS: Bool)] = [
      (UILabel(), true),
      (UIImageView(image: UIImage(systemName: "star")), true),
      (UIButton(type: .system), true),
      (UITextView(), true),
      (UITextField(), true),
      (UIView(), false),
      (UIImageView(), false),
      (UISwitch(), false),
      (UIScrollView(), false),
      (TextLabelView(), false),
      (BaseTextView(), false),
      (ComposeView { LabelNode("text") }, false),
    ]

    // when: adding the views to a window
    for (view, _) in views {
      window.contentView.addSubview(view)
    }

    // then: on visionOS, the layers of some views are in wrapper layers, while on iOS each layer is in its superview's
    for (view, isWrappedOnVisionOS) in views {
      #if os(visionOS)
      expect(view.layer.superlayer !== window.contentView.layer, "\(type(of: view)) is wrapped") == isWrappedOnVisionOS
      #else
      expect(view.layer.superlayer, "\(type(of: view))'s superlayer") === window.contentView.layer
      #endif
    }
  }

  #if os(visionOS)

  func test_wrapsAnImageViewsLayer_whenTheImageViewGetsAnImage() throws {
    // given: an image view without an image in a window, at a frame
    let window = try makeHostWindow()
    let imageView = UIImageView()
    window.contentView.addSubview(imageView)
    imageView.frame = Constants.frame

    // then: the image view's layer isn't wrapped
    expect(imageView.layer.superlayer) === window.contentView.layer

    // when: setting an image
    imageView.image = UIImage(systemName: "star")

    // then: the image view's layer is wrapped at once, and the image view keeps its frame
    let wrapper = try unwrap(imageView.layer.superlayer)
    expect(wrapper) !== window.contentView.layer
    expect(imageView.frame) == Constants.frame
    expect(imageView.layer.position) == Constants.boundsCenter

    // when: removing the image
    imageView.image = nil
    RunLoop.main.run(until: Date())

    // then: the image view's layer stays wrapped
    expect(imageView.layer.superlayer) === wrapper

    // when: removing the image view from the window
    imageView.removeFromSuperview()

    // then: the image view's layer stays in its wrapper
    expect(imageView.layer.superlayer) === wrapper
  }

  func test_wrappedView_frame() throws {
    // given: a label in a window, whose layer is wrapped
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    let wrapper = try unwrap(label.layer.superlayer)
    expect(wrapper) !== window.contentView.layer

    // when: setting the label's frame
    label.frame = Constants.frame

    // then: the wrapper takes the frame, which the label's frame and center read
    expect(label.frame) == Constants.frame
    expect(label.center) == Constants.frameCenter
    expect(wrapper.position) == Constants.frameCenter
    expect(wrapper.bounds.size) == Constants.frame.size
    expect(wrapper.anchorPoint) == CGPoint(x: 0.5, y: 0.5)
    expect(CATransform3DIsIdentity(wrapper.transform)) == true

    // then: the label's layer fills the wrapper, which the label's bounds read
    expect(label.layer.position) == Constants.boundsCenter
    expect(label.layer.bounds.size) == Constants.frame.size
    expect(label.bounds.size) == Constants.frame.size
  }

  func test_wrappedView_anchorPoint() throws {
    // given: a label in a window, whose layer has its anchor point at its top left corner
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    let wrapper = try unwrap(label.layer.superlayer)
    label.layer.anchorPoint = .zero

    // when: setting the label's frame
    label.frame = Constants.frame

    // then: the wrapper keeps its anchor point at its center, and the label's layer stays at the wrapper's bounds center
    expect(label.center) == Constants.frameCenter
    expect(wrapper.position) == Constants.frameCenter
    expect(wrapper.anchorPoint) == CGPoint(x: 0.5, y: 0.5)
    expect(label.layer.position) == Constants.boundsCenter
  }

  func test_wrappedView_layerWrites() throws {
    // given: a label in a window, at a frame
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    let wrapper = try unwrap(label.layer.superlayer)
    label.frame = Constants.frame

    // when: moving the label's layer
    label.layer.position = CGPoint(x: 300, y: 200)

    // then: the layer moves in the wrapper, which stays, and so does the label's frame
    expect(wrapper.position) == Constants.frameCenter
    expect(label.frame) == Constants.frame

    // when: resizing the label's layer
    label.layer.bounds.size = CGSize(width: 120, height: 60)

    // then: the label's bounds follow the layer, while the wrapper and the label's frame keep their size
    expect(label.bounds.size) == CGSize(width: 120, height: 60)
    expect(wrapper.bounds.size) == Constants.frame.size
    expect(label.frame) == Constants.frame
  }

  func test_wrappedView_settingTheFrame_resetsTheLayer() throws {
    // given: a label in a window, whose layer moved and resized in its wrapper
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    label.frame = Constants.frame
    label.layer.position = CGPoint(x: 300, y: 200)
    label.layer.bounds.size = CGSize(width: 120, height: 60)

    // when: setting the label's frame again, unchanged
    label.frame = Constants.frame

    // then: the label's layer fills the wrapper again
    expect(label.layer.position) == Constants.boundsCenter
    expect(label.layer.bounds.size) == Constants.frame.size
  }

  func test_wrappedView_layerTransform() throws {
    // given: a label in a window, at a frame
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    let wrapper = try unwrap(label.layer.superlayer)
    label.frame = Constants.frame

    // when: transforming the label's layer
    label.layer.transform = CATransform3DMakeScale(2, 2, 1)

    // then: the transform stays on the layer, and the wrapper and the label's frame don't change
    expect(CATransform3DIsIdentity(wrapper.transform)) == true
    expect(label.frame) == Constants.frame
    expect(label.center) == Constants.frameCenter
  }

  #endif

  // MARK: - Constants

  private enum Constants {

    /// The frame to give a view.
    static let frame = CGRect(x: 100, y: 50, width: 80, height: 40)

    /// The center of `frame`.
    static let frameCenter = CGPoint(x: 140, y: 70)

    /// The center of the bounds of a view at `frame`.
    static let boundsCenter = CGPoint(x: 40, y: 20)
  }
}
