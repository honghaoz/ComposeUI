//
//  CALayer+AdditivePath.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/24/26.
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

import QuartzCore

public extension CALayer {

  /// Animate a path of the layer additively.
  ///
  /// The change stacks on the path's changes in flight, the way an additive animation stacks on a number: the path shown
  /// is the model path plus the part of each change that is left, so an interrupted change keeps its motion. Core
  /// Animation can't add path animations together, so each call replaces the key path's animation with one that shows
  /// the sum of the changes.
  ///
  /// The changes add point by point, so the paths need the same segments: the same kinds of elements in the same order.
  /// A path with other segments, or with points that aren't finite, as a null rect gives, drops the changes in flight
  /// and shows at once. A layer without a path at the key path has nothing to animate from, so the path shows at once
  /// too.
  ///
  /// - Important: The key path must hold a `CGPath`, such as `shadowPath` or `CAShapeLayer`'s `path`.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - path: The path to animate to.
  ///   - timing: The animation timing.
  @_spi(Private)
  func animatePath(keyPath: String, to path: CGPath, timing: AnimationTiming) {
    // TODO: needs to guard check the keyPath is a path

    let now = currentTime
    var changes = pathChanges(forKeyPath: keyPath, at: now)
    if let currentPath = modelPath(forKeyPath: keyPath) {
      guard currentPath != path else {
        return
      }
      changes.record(from: currentPath, to: path, timing: timing, at: now)
    }
    showPath(path, forKeyPath: keyPath, changes: changes, at: now)
  }

  /// Set a path of the layer without animation.
  ///
  /// The path's changes in flight keep adding to the new path, the way additive animations keep adding to a model value
  /// that changes, so the path shown moves by the change of the model path, see `animatePath(keyPath:to:timing:)`.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - path: The path to set.
  @_spi(Private)
  func setPath(keyPath: String, to path: CGPath) {
    // TODO: needs to guard check the keyPath is a path

    guard modelPath(forKeyPath: keyPath) != path else {
      return
    }
    let now = currentTime
    showPath(path, forKeyPath: keyPath, changes: pathChanges(forKeyPath: keyPath, at: now), at: now)
  }
}

private extension CALayer {

  /// The path's changes in flight, kept on the animation that shows them.
  func pathChanges(forKeyPath keyPath: String, at now: TimeInterval) -> PathChanges {
    guard let animation = animation(forKey: keyPath), let box = animation.value(forKey: PathChangesBox.key) as? PathChangesBox else {
      return PathChanges()
    }
    var changes = box.changes
    changes.update(beginTime: animation.beginTime, at: now)
    return changes
  }

  /// Sets the model path, and shows it with the changes in flight.
  func showPath(_ path: CGPath, forKeyPath keyPath: String, changes: PathChanges, at now: TimeInterval) {
    guard !changes.isEmpty else {
      showPathAtOnce(path, forKeyPath: keyPath)
      return
    }

    let points = PathPoints(path)
    guard changes.hasSameSegments(as: points), points.isFinite else {
      showPathAtOnce(path, forKeyPath: keyPath)
      return
    }

    let animation: CAPropertyAnimation
    if changes.changes.count == 1 {
      // one change is an animation between two paths, which Core Animation evaluates on every frame. it is a copy of the
      // change's own animation, since the changes stored on it hold that animation, which would then hold itself
      let change = changes.changes[0]
      let basicAnimation = change.animation.copy() as! CABasicAnimation // swiftlint:disable:this force_cast
      basicAnimation.keyPath = keyPath
      basicAnimation.fromValue = points.adding(change.offset).path
      basicAnimation.toValue = path
      animation = basicAnimation
    } else {
      // the samples are measured from now once a change has begun, so the keyframes begin now too. otherwise every
      // change begins at the next commit, and so do the keyframes
      let times = changes.sampleTimes(at: now)
      let keyframeAnimation = CAKeyframeAnimation(keyPath: keyPath)
      keyframeAnimation.values = times.map { changes.points(adding: points, at: $0, now: now)?.path ?? path }
      keyframeAnimation.keyTimes = times.indices.map { NSNumber(value: TimeInterval($0) / TimeInterval(times.count - 1)) }
      keyframeAnimation.calculationMode = .linear
      keyframeAnimation.duration = changes.remainingTime(at: now)
      keyframeAnimation.fillMode = .both
      if changes.hasResolvedBeginTime {
        keyframeAnimation.beginTime = now
      }
      animation = keyframeAnimation
    }

    animation.setValue(PathChangesBox(changes), forKey: PathChangesBox.key)
    add(animation, forKey: keyPath)
    setKeyPathValue(keyPath, path)
  }

  /// Sets the model path, and removes the animation of the changes in flight, so the path shows at once.
  func showPathAtOnce(_ path: CGPath, forKeyPath keyPath: String) {
    if animation(forKey: keyPath)?.value(forKey: PathChangesBox.key) is PathChangesBox {
      removeAnimation(forKey: keyPath)
    }
    setKeyPathValue(keyPath, path)
  }

  /// The model path at a key path.
  func modelPath(forKeyPath keyPath: String) -> CGPath? {
    guard let value = value(forKeyPath: keyPath) else {
      return nil
    }

    let object = value as AnyObject
    guard CFGetTypeID(object) == CGPath.typeID else {
      ComposeUI.assertFailure("expected a path at \"\(keyPath)\", got \(value)")
      return nil
    }
    return unsafeDowncast(object, to: CGPath.self)
  }
}

/// The changes of a path in flight, kept on the animation that shows them, so they end with it.
private final class PathChangesBox {

  /// The key of the box on the animation.
  static let key = "ComposeUI.pathChanges"

  /// The changes.
  let changes: PathChanges

  init(_ changes: PathChanges) {
    self.changes = changes
  }
}
