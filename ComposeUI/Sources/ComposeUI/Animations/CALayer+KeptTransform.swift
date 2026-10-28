//
//  CALayer+KeptTransform.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/28/26.
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

extension CALayer {

  /// Keeps the layer's transform through AppKit's resets of a view's layer transform.
  ///
  /// AppKit resets a layer-backed view's layer transform to identity when the view moves or resizes, and at the first
  /// commit after the view joins a window. The layer puts the kept transform back whenever its transform becomes
  /// identity, during the reset, so no frame shows the view without it. Keeping identity stops the keeping, and so do
  /// `stopKeepingTransform()` and `restoreIdentityTransformIfNeeded()`.
  ///
  /// - Parameter transform: The transform to keep.
  func keepTransform(_ transform: CATransform3D) {
    guard !CATransform3DIsIdentity(transform) else {
      stopKeepingTransform()
      return
    }

    if let keeper = objc_getAssociatedObject(self, TransformKeeper.key) as? TransformKeeper {
      keeper.transform = transform
      keeper.isPaused = false
    } else {
      let keeper = TransformKeeper(layer: self, transform: transform)
      objc_setAssociatedObject(self, TransformKeeper.key, keeper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
  }

  /// Stops putting the kept transform back until `resumeKeepingTransform(mayBeKeeping:)`, so that the code in between
  /// can change the transform, to identity too.
  ///
  /// - Returns: Whether the layer can be keeping a transform, which a layer with the identity transform isn't, since it
  ///   would have put a kept transform back.
  func pauseKeepingTransform() -> Bool {
    // the render pass pauses every view, so the cheapest check that rules out a keeper goes first, then the transform,
    // which costs less to read than the keeper to look up
    guard TransformKeeper.count > 0, !CATransform3DIsIdentity(transform) else {
      return false
    }
    (objc_getAssociatedObject(self, TransformKeeper.key) as? TransformKeeper)?.isPaused = true
    return true
  }

  /// Keeps the transform that the code since `pauseKeepingTransform()` left, or stops keeping when it left identity.
  ///
  /// - Parameter mayBeKeeping: What `pauseKeepingTransform()` returned.
  func resumeKeepingTransform(mayBeKeeping: Bool) {
    let transform = self.transform
    if !CATransform3DIsIdentity(transform) {
      keepTransform(transform)
    } else if mayBeKeeping {
      stopKeepingTransform()
    }
  }

  /// Stops keeping the layer's transform, see `keepTransform(_:)`.
  func stopKeepingTransform() {
    // the layer has the only reference to its keeper, so the keeper goes, and its observation with it
    objc_setAssociatedObject(self, TransformKeeper.key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }
}

/// Puts a layer's kept transform back when the layer's transform becomes identity, see `CALayer.keepTransform(_:)`.
///
/// It's kept on the layer as an associated object, since a layer holds a value that it stores for a key until the
/// transaction commits, which would keep a removed keeper putting the transform back.
private final class TransformKeeper {

  /// The key of the keeper on a layer, a stable address.
  static let key = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

  /// The number of keepers alive.
  ///
  /// Keepers are made and released on the main thread, where the views whose layers keep them live.
  static var count = 0

  /// The transform to keep, which isn't identity.
  var transform: CATransform3D

  /// Whether the keeper leaves the transform alone, see `CALayer.pauseKeepingTransform()`.
  var isPaused = false

  /// The observation of the layer's transform.
  private var observation: NSKeyValueObservation?

  /// Creates a keeper that keeps the layer's transform.
  ///
  /// - Parameters:
  ///   - layer: The layer, which keeps the keeper.
  ///   - transform: The transform to keep.
  init(layer: CALayer, transform: CATransform3D) {
    self.transform = transform
    Self.count += 1

    // AppKit resets the transform through its setter, which the observation sees, and only to identity, so only
    // identity is put back, which leaves a transform that other code sets, such as a scale transition's
    observation = layer.observe(\.transform) { [weak self] layer, _ in
      guard let self, !isPaused, CATransform3DIsIdentity(layer.transform) else {
        return
      }
      layer.setKeyPathValue("transform", NSValue(caTransform3D: self.transform))
    }
  }

  deinit {
    Self.count -= 1
  }
}
#endif
