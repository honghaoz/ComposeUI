//
//  ComposeContentView.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

/// A view that renders `ComposeContent`.
open class ComposeContentView: UIScrollView {

  /// An overridable content builder for the content view.
  @ComposeContentBuilder
  var content: ComposeContent {
    LabelNode("Hello ComposeUI!")
  }

  /// The block to make content.
  private var makeContent: ((ComposeContentView) -> ComposeContent)!

  /// The current content node that the content view is rendering.
  private var contentNode: ContentNode?

  /// The context of the current content update.
  private var contentUpdateContext: ContentUpdateContext?

  /// The bounds used for last render pass.
  private lazy var lastRenderBounds: CGRect = .zero

  /// The ids of the view items that the content view is rendering.
  private var viewItemIds: [String] = []

  /// The map of the view items that the content view is rendering.
  private var viewItemMap: [String: ViewItem<UIView>] = [:]

  /// The map of the views that the content view is rendering.
  private var viewMap: [String: UIView] = [:]

  /// Creates a `ComposeContentView` with the given content.
  public init(@ComposeContentBuilder content: @escaping (ComposeContentView) -> ComposeContent) {
    super.init(frame: .zero)

    makeContent = content
    commonInit()
  }

  /// Creates a `ComposeContentView` with the given content.
  public init(@ComposeContentBuilder content: @escaping () -> ComposeContent) {
    super.init(frame: .zero)

    makeContent = { _ in content() }
    commonInit()
  }

  /// Creates a `ComposeContentView` with `content`. This is useful for subclassing.
  init() {
    super.init(frame: .zero)

    makeContent = { [unowned self] _ in content } // swiftlint:disable:this unowned_variable
    commonInit()
  }

  @available(*, unavailable)
  public override init(frame: CGRect) {
    // swiftlint:disable:next fatal_error
    fatalError("init(frame:) is unavailable")
  }

  @available(*, unavailable)
  required public init?(coder: NSCoder) {
    // swiftlint:disable:next fatal_error
    fatalError("init(coder:) is unavailable")
  }

  private func commonInit() {
    #if !os(visionOS)
    contentScaleFactor = UIScreen.main.scale
    #endif
    contentInsetAdjustmentBehavior = .never // to ensure the content inset is consistent
  }

  /// Set the content closure for the content view.
  func setContent(@ComposeContentBuilder content: @escaping (ComposeContentView) -> ComposeContent) {
    makeContent = content
  }

  /// Set the content closure for the content view.
  func setContent(@ComposeContentBuilder content: @escaping () -> ComposeContent) {
    makeContent = { _ in content() }
  }

  open override func sizeThatFits(_ size: CGSize) -> CGSize {
    var contentNode = makeContent(self).asVStack(alignment: .center)
    _ = contentNode.layout(containerSize: size)
    return contentNode.size.roundedUp(scaleFactor: contentScaleFactor)
  }

  /// Refreshes the content view by making a new content node and rendering the content.
  public func refresh(animated: Bool = true) {
    // explicit render request, should make a new content
    contentNode = ContentNode(node: makeContent(self).asVStack(alignment: .center))
    contentUpdateContext = ContentUpdateContext(updateType: .refresh(isAnimated: animated))

    setNeedsLayout()
    layoutIfNeeded()
  }

  open override func layoutSubviews() {
    super.layoutSubviews()

    if contentUpdateContext == nil, bounds != lastRenderBounds {
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
    lastRenderBounds = bounds
  }

  private func render(_ context: ContentUpdateContext) {
    guard let contentNode else {
      return
    }

    // do the layout
    // TODO: how to maintain a matched content offset?
    _ = contentNode.layout(containerSize: bounds.size)

    // TODO: check if the content is larger than the container
    // if not, should use frame to center the content

    contentSize = contentNode.size.roundedUp(scaleFactor: contentScaleFactor)

    let viewItems = contentNode.viewItems(in: bounds)

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
      let id = viewItem.id
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
      
      let view: UIView
      if reusingIds.contains(id) {
        // [2/3] reuse the view item that is still in the content
        view = oldViewMap[id]! // swiftlint:disable:this force_unwrapping

        view.reset()

        bringSubviewToFront(view)

        if context.isAnimated {
          // TODO: add animations onto nodes
          UIView.animate(withDuration: 0.25) {
            view.frame = viewItem.frame.rounded(scaleFactor: self.contentScaleFactor)
            viewItem.update(view)
          }
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
        addSubview(view)

        viewItem.update(view)
      }

      viewMap[id] = view
    }
  }
}

// MARK: - Helpers

private extension UIView {

  /// Common reset for the view managed by `ComposeContentView`.
  ///
  /// To ensure the frame update is applied correctly, the transform is reset to identity.
  func reset() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    // frame update requires an identity transform
    layer.transform = CATransform3DIdentity

    CATransaction.commit()
  }
}

private extension CGRect {

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

  func round(nearest: CGFloat) -> CGFloat {
    let n = 1 / nearest
    let numberToRound = self * n
    return numberToRound.rounded() / n
  }

  /// Rounds up the value to the nearest value based on the given nearest value.
  ///
  /// For example, `1.0.ceil(nearest: 0.5)` returns `1.0` and `1.1.ceil(nearest: 0.5)` returns `1.5`.
  func ceil(nearest: CGFloat) -> CGFloat {
    let remainder = truncatingRemainder(dividingBy: nearest)
    if abs(remainder) <= 1e-12 {
      return self
    } else {
      return self + (nearest - remainder)
    }
  }
}
