//
//  RenderableTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/31/26.
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

#if os(visionOS)

import ChouTiTest
import UIKit

@testable import ComposeUI

/// Tests the frame of a view whose layer visionOS moves into a wrapper layer, such as a label.
class RenderableTests: XCTestCase {

  func test_frame_viewInWrapperLayer() throws {
    // given: a label in a window, whose layer is in a wrapper layer, at a frame
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    let renderable = Renderable.view(label)
    renderable.setFrame(Constants.frame)

    // when: transforming the label's layer
    label.layer.transform = CATransform3DMakeScale(2, 2, 1)

    // then: the frame is the one set, which the transform doesn't change
    expect(renderable.frame) == Constants.frame

    // given: a transformed plain view in the window, whose layer isn't wrapped, at the frame
    let view = UIView()
    window.contentView.addSubview(view)
    Renderable.view(view).setFrame(Constants.frame)
    view.layer.transform = CATransform3DMakeScale(2, 2, 1)

    // then: the frame is the one set
    expect(view.layer.superlayer) === window.contentView.layer
    expect(Renderable.view(view).frame) == Constants.frame
  }

  func test_hasFrame_viewInWrapperLayer() throws {
    // given: a label in a window, whose layer is in a wrapper layer, at a frame
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    let renderable = Renderable.view(label)
    renderable.setFrame(Constants.frame)

    // then: the label has the frame, and not another origin or size
    expect(renderable.hasFrame(Constants.frame)) == true
    expect(renderable.hasFrame(Constants.frame.translate(dx: 10))) == false
    expect(renderable.hasFrame(CGRect(origin: Constants.frame.origin, size: CGSize(width: 90, height: 40)))) == false

    // when: moving the label's layer in its wrapper
    label.layer.position = CGPoint(x: 300, y: 200)

    // then: the label doesn't have the frame
    expect(renderable.hasFrame(Constants.frame)) == false

    // when: setting the frame again, then resizing the label's layer in its wrapper
    renderable.setFrame(Constants.frame)
    expect(renderable.hasFrame(Constants.frame)) == true
    label.layer.bounds.size = CGSize(width: 120, height: 60)

    // then: the label doesn't have the frame
    expect(renderable.hasFrame(Constants.frame)) == false

    // given: a plain view in the window, whose layer isn't wrapped, at the frame
    let view = UIView()
    window.contentView.addSubview(view)
    Renderable.view(view).setFrame(Constants.frame)

    // then: the view has the frame
    expect(view.layer.superlayer) === window.contentView.layer
    expect(Renderable.view(view).hasFrame(Constants.frame)) == true
    expect(Renderable.view(view).hasFrame(Constants.frame.translate(dx: 10))) == false
  }

  func test_updateFrame_viewInWrapperLayer_withTiming() throws {
    // given: a label in a window, whose layer is in a wrapper layer, at a frame
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    let renderable = Renderable.view(label)
    renderable.setFrame(Constants.frame)

    // when: updating the frame with a timing
    renderable.updateFrame(Constants.movedFrame, animationTiming: .linear(duration: 1))

    // then: the label takes the frame without animating it, with its layer filling the wrapper
    expect(label.frame) == Constants.movedFrame
    expect(label.layer.position) == Constants.boundsCenter
    expect(label.layer.animationKeys()) == nil
    expect(renderable.hasFrame(Constants.movedFrame)) == true

    // given: a plain view and a layer in the window, which aren't wrapped, at the frame
    let view = UIView()
    window.contentView.addSubview(view)
    let layer = CALayer()
    window.contentView.layer.addSublayer(layer)
    let unwrappedRenderables = [Renderable.view(view), Renderable.layer(layer)]
    for renderable in unwrappedRenderables {
      renderable.setFrame(Constants.frame)
    }

    // when: updating their frames with a timing
    for renderable in unwrappedRenderables {
      renderable.updateFrame(Constants.movedFrame, animationTiming: .linear(duration: 1))
    }

    // then: they animate to the frame
    for renderable in unwrappedRenderables {
      expect(renderable.frame) == Constants.movedFrame
      expect(renderable.layer.animationKeys()?.contains("position")) == true
    }
  }

  func test_updateFrame_viewInWrapperLayer_withAnimationsInFlight() throws {
    // given: a label in a window, whose layer is in a wrapper layer, at a frame, with an animation in flight
    let window = try makeHostWindow()
    let label = UILabel()
    window.contentView.addSubview(label)
    let renderable = Renderable.view(label)
    renderable.setFrame(Constants.frame)
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = 0
    animation.duration = 1
    label.layer.add(animation, forKey: "fade")

    // when: updating the frame without a timing
    renderable.updateFrame(Constants.movedFrame, animationTiming: nil)

    // then: the label takes the frame, with its layer filling the wrapper
    expect(label.frame) == Constants.movedFrame
    expect(label.layer.position) == Constants.boundsCenter
    expect(renderable.hasFrame(Constants.movedFrame)) == true
  }

  func test_render_viewInWrapperLayer() throws {
    // given: a compose view in a window, which shows a label at a frame
    let window = try makeHostWindow()
    var left: CGFloat = 10
    var shownLabel: FrameCountingLabel?
    let composeView = ComposeView {
      ViewNode(make: { context in
        let label = FrameCountingLabel(frame: context.initialFrame ?? .zero)
        label.text = "label"
        shownLabel = label
        return label
      })
      .animation(.linear(duration: 1))
      .frame(width: 80, height: 40)
      .padding(top: 20, left: left)
      .frame(width: .flexible, height: .flexible, alignment: .topLeft)
    }
    composeView.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
    window.contentView.addSubview(composeView)

    // when: rendering
    composeView.refresh(animated: false)

    // then: the label's layer is in a wrapper layer, and the label is at its frame
    let label = try unwrap(shownLabel)
    expect(label.layer.superlayer) !== label.superview?.layer
    expect(label.frame) == CGRect(x: 10, y: 20, width: 80, height: 40)
    expect(label.layer.position) == Constants.boundsCenter

    // when: rendering again, unchanged
    let frameSetCount = label.frameSetCount
    composeView.refresh(animated: false)
    composeView.refresh(animated: true)

    // then: the label's frame isn't set again
    expect(label.frameSetCount) == frameSetCount

    // when: moving the label in an animated refresh
    left = 50
    composeView.refresh(animated: true)

    // then: the label takes its frame without animating it, with its layer filling the wrapper
    expect(label.frame) == CGRect(x: 50, y: 20, width: 80, height: 40)
    expect(label.layer.position) == Constants.boundsCenter
    expect(label.layer.animationKeys()) == nil
  }

  // MARK: - Constants

  private enum Constants {

    /// The frame to give a view.
    static let frame = CGRect(x: 100, y: 50, width: 80, height: 40)

    /// The frame to move a view to.
    static let movedFrame = CGRect(x: 160, y: 90, width: 80, height: 40)

    /// The center of the bounds of a view at `frame`.
    static let boundsCenter = CGPoint(x: 40, y: 20)
  }
}

/// A label that counts how often its frame is set.
private final class FrameCountingLabel: UILabel {

  private(set) var frameSetCount = 0

  override var frame: CGRect {
    didSet {
      frameSetCount += 1
    }
  }
}

#endif
