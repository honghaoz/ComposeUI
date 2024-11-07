//
//  ComposeContentView.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// A view that renders `ComposeContent`.
open class ComposeContentView: BaseScrollView {

  /// The content for the view.
  ///
  /// This is overridable so that a subclass can provide a content.
  var content: ComposeContent {
    Empty()
  }

  /// The block to make content.
  private var makeContent: (ComposeContentView) -> ComposeContent

  /// The current content node that the content view is rendering.
  private var contentNode: ContentNode?

  /// The context of the current content update.
  private var contentUpdateContext: ContentUpdateContext?

  /// The bounds used for last render pass.
  private lazy var lastRenderBounds: CGRect = .zero

  /// The ids of the view items that the content view is rendering.
  private var viewItemIds: [String] = []

  /// The map of the view items that the content view is rendering.
  private var viewItemMap: [String: ViewItem<View>] = [:]

  /// The map of the views that the content view is rendering.
  private var viewMap: [String: View] = [:]

  /// Creates a `ComposeContentView` with the given content, passing in the content view.
  ///
  /// - Parameter content: The content builder block.
  public init(@ComposeContentBuilder content: @escaping (ComposeContentView) -> ComposeContent) {
    self.makeContent = content

    super.init(frame: .zero)

    commonInit()
  }

  /// Creates a `ComposeContentView` with the given content.
  ///
  /// - Parameter content: The content builder block.
  public init(@ComposeContentBuilder content: @escaping () -> ComposeContent) {
    makeContent = { _ in content() }

    super.init(frame: .zero)

    commonInit()
  }

  /// Creates a `ComposeContentView` with `content`.
  init() {
    makeContent = { _ in Empty() }

    super.init(frame: .zero)

    makeContent = { [unowned self] _ in content } // swiftlint:disable:this unowned_variable
    commonInit()
  }

  @available(*, unavailable)
  override public init(frame: CGRect) {
    fatalError("init(frame:) is unavailable") // swiftlint:disable:this fatal_error
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  private func commonInit() {
    #if canImport(UIKit)
    contentInsetAdjustmentBehavior = .never // ensure the content inset is consistent
    #endif
  }

  /// Set a new content.
  ///
  /// - Parameter content: The content builder block, passing in the content view.
  func setContent(@ComposeContentBuilder content: @escaping (ComposeContentView) -> ComposeContent) {
    makeContent = content
  }

  /// Set a new content.
  ///
  /// - Parameter content: The content builder block.
  func setContent(@ComposeContentBuilder content: @escaping () -> ComposeContent) {
    makeContent = { _ in content() }
  }

  #if canImport(UIKit)
  /// Get the size that fits the content.
  ///
  /// - Parameter size: The container size.
  /// - Returns: The size that fits the content.
  override open func sizeThatFits(_ size: CGSize) -> CGSize {
    _sizeThatFits(size)
  }
  #else
  /// Get the size that fits the content.
  ///
  /// - Parameter size: The container size.
  /// - Returns: The size that fits the content.
  open func sizeThatFits(_ size: CGSize) -> CGSize {
    _sizeThatFits(size)
  }
  #endif

  private func _sizeThatFits(_ size: CGSize) -> CGSize {
    var contentNode = makeContent(self).asVStack(alignment: .center)
    _ = contentNode.layout(containerSize: size)
    return contentNode.size.roundedUp(scaleFactor: contentScaleFactor)
  }

  /// Refreshes and re-renders the content.
  ///
  /// This call will make a new content from the builder block and re-render the content.
  ///
  /// - Parameter animated: Whether the refresh is animated.
  public func refresh(animated: Bool = true) {
    // explicit render request, should make a new content
    contentNode = ContentNode(node: makeContent(self).asVStack(alignment: .center))
    contentUpdateContext = ContentUpdateContext(updateType: .refresh(isAnimated: animated))

    setNeedsLayout()
    layoutIfNeeded()
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    if contentUpdateContext == nil, bounds() != lastRenderBounds {
      // no explicit render request, this is a bounds change update
      if contentNode == nil {
        contentNode = ContentNode(node: makeContent(self).asVStack(alignment: .center))
      }
      contentUpdateContext = ContentUpdateContext(updateType: .boundsChange)
    }

    guard var contentUpdateContext, !contentUpdateContext.isRendering else {
      return
    }

    contentUpdateContext.isRendering = true
    self.contentUpdateContext = contentUpdateContext

    render(contentUpdateContext)

    self.contentUpdateContext = nil
    lastRenderBounds = bounds()
  }

  private func render(_ context: ContentUpdateContext) {
    guard let contentNode else {
      return
    }

    // do the layout
    // TODO: how to maintain a matched content offset?
    _ = contentNode.layout(containerSize: bounds().size)

    // TODO: check if the content is larger than the container
    // if not, should use frame to center the content

    setContentSize(contentNode.size.roundedUp(scaleFactor: contentScaleFactor))

    let viewItems = contentNode.viewItems(in: bounds())

    // set up the view item ids and map
    let oldViewItemIds = viewItemIds
    let oldViewMap = viewMap

    viewItemIds = []
    viewItemIds.reserveCapacity(viewItems.count)
    viewItemMap = [:]
    viewItemMap.reserveCapacity(viewItems.count)
    viewMap = [:]
    viewMap.reserveCapacity(viewItems.count)

    for viewItem in viewItems {
      let id = viewItem.id.id
      viewItemIds.append(id)
      assert(viewItemMap[id] == nil, "conflicting view item id: \(id)")
      viewItemMap[id] = viewItem
    }

    // update the views
    var reusingIds: Set<String> = []

    for oldId in oldViewItemIds {
      if viewItemMap[oldId] == nil {
        // [1/3] remove the view item that are no longer in the content
        let oldView = oldViewMap[oldId]

        // TODO: add transition animations
        oldView?.removeFromSuperview()
      } else {
        // this view item is still in the content, plan to reuse it
        reusingIds.insert(oldId)
      }
    }

    for id in viewItemIds {
      let viewItem = viewItemMap[id]! // swiftlint:disable:this force_unwrapping

      let view: View
      if reusingIds.contains(id) {
        // [2/3] reuse the view item that is still in the content
        view = oldViewMap[id]! // swiftlint:disable:this force_unwrapping

        view.reset()

        contentView().bringSubviewToFront(view)

        if context.isAnimated {
          // TODO: add animations on nodes
          #if canImport(UIKit)
          UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.3,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: {
              view.frame = viewItem.frame.rounded(scaleFactor: self.contentScaleFactor)
              viewItem.update(view)
            }
          )
          #elseif canImport(AppKit)
          NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.animator().frame = viewItem.frame.rounded(scaleFactor: self.contentScaleFactor)
            viewItem.update(view.animator())
          }
          #endif
        } else {
          view.frame = viewItem.frame.rounded(scaleFactor: contentScaleFactor)
          viewItem.update(view)
        }
      } else {
        // [3/3] insert the view item that is new
        view = viewItem.make()

        view.reset()

        view.frame = viewItem.frame.rounded(scaleFactor: contentScaleFactor)

        // TODO: add transition animations
        contentView().addSubview(view)

        viewItem.update(view)
      }

      viewMap[id] = view
    }
  }
}

// MARK: - Helpers

private extension View {

  /// Common reset for the view managed by `ComposeContentView`.
  ///
  /// To ensure the frame update is applied correctly, the transform is reset to identity.
  func reset() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    // frame update requires an identity transform
    layer().transform = CATransform3DIdentity

    CATransaction.commit()
  }
}

private extension CGRect {

  /// Rounds the rectangle to the nearest pixel size based on the given scale factor.
  /// So that the view can be rendered without subpixel rendering artifacts.
  ///
  /// - Parameter scaleFactor: The scale factor of the screen.
  /// - Returns: The rounded rectangle.
  func rounded(scaleFactor: CGFloat) -> CGRect {
    if isNull || isInfinite {
      return self
    }

    let pixelWidth: CGFloat = 1 / scaleFactor

    let x = origin.x.round(nearest: pixelWidth)
    let y = origin.y.round(nearest: pixelWidth)
    let width = width.round(nearest: pixelWidth)
    let height = height.round(nearest: pixelWidth)
    return CGRect(x: x, y: y, width: width, height: height)
  }
}

private extension CGSize {

  /// Rounds up the size to the nearest pixel size based on the given scale factor.
  ///
  /// For example, `CGSize(width: 49.9, height: 50.0).roundedUp(scaleFactor: 2.0)` returns `CGSize(width: 50.0, height: 50.0)`.
  ///
  /// - Parameter scaleFactor: The scale factor of the screen.
  /// - Returns: The rounded size.
  func roundedUp(scaleFactor: CGFloat) -> CGSize {
    guard scaleFactor > 0 else {
      return self
    }

    let pixelWidth: CGFloat = 1 / scaleFactor
    let width = width.ceil(nearest: pixelWidth)
    let height = height.ceil(nearest: pixelWidth)
    return CGSize(width: width, height: height)
  }
}

private extension CGFloat {

  /// Rounds the value to the nearest value based on the given nearest value.
  ///
  /// For example, `1.1.round(nearest: 0.5)` returns `1.0` and `1.4.round(nearest: 0.5)` returns `1.5`.
  ///
  /// - Parameter nearest: The nearest value, usually this is 1 divided by the scale factor of the screen.
  /// - Returns: The rounded value.
  func round(nearest: CGFloat) -> CGFloat {
    let n = 1 / nearest
    let numberToRound = self * n
    return numberToRound.rounded() / n
  }

  /// Rounds up the value to the nearest value based on the given nearest value.
  ///
  /// For example, `1.0.ceil(nearest: 0.5)` returns `1.0` and `1.1.ceil(nearest: 0.5)` returns `1.5`.
  ///
  /// - Parameter nearest: The nearest value, usually this is 1 divided by the scale factor of the screen.
  /// - Returns: The rounded value.
  func ceil(nearest: CGFloat) -> CGFloat {
    let remainder = truncatingRemainder(dividingBy: nearest)
    if abs(remainder) <= 1e-12 {
      return self
    } else {
      return self + (nearest - remainder)
    }
  }
}
