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

import ObjectiveC
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
  /// and shows at once. A layer without a path at the key path has nothing to animate from, and nothing for the
  /// changes in flight to add to, so it drops them and shows the path at once too.
  ///
  /// - Important: The key path must hold a `CGPath`, such as `shadowPath` or `CAShapeLayer`'s `path`. A key path that
  ///   holds another value asserts, and the layer is left alone.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - path: The path to animate to.
  ///   - timing: The animation timing.
  @_spi(Private)
  func animatePath(keyPath: String, to path: CGPath, timing: AnimationTiming) {
    animatePath(keyPath: keyPath, timing: timing, resizingFrom: { _ in nil }, to: { _ in path })
  }

  /// Set a path of the layer without animation.
  ///
  /// The path's changes in flight keep adding to the new path, the way additive animations keep adding to a model value
  /// that changes, so the path shown moves by the change of the model path, see `animatePath(keyPath:to:timing:)`. A
  /// layer without a path at the key path has nothing for the changes in flight to add to, so it drops them and shows
  /// the path at once.
  ///
  /// - Important: The key path must hold a `CGPath`, such as `shadowPath` or `CAShapeLayer`'s `path`. A key path that
  ///   holds another value asserts, and the layer is left alone.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - path: The path to set.
  @_spi(Private)
  func setPath(keyPath: String, to path: CGPath) {
    switch modelPath(forKeyPath: keyPath) {
    case .path(let currentPath):
      guard currentPath != path else {
        return
      }
      let now = currentTime
      showPath(path, points: nil, forKeyPath: keyPath, changes: pathChanges(forKeyPath: keyPath, at: now), at: now)
    case .noValue:
      showPathAtOnce(path, forKeyPath: keyPath)
    case .notAPath:
      return
    }
  }

  /// Set a path of the layer and retarget its changes in flight to it, so the path shown glides from where it is to the
  /// new path and lands when the changes would have, as `retarget(keyPath:to:)` does for a value.
  ///
  /// Each coordinate of the path's points is judged on its own: one that the changes in flight move glides from where it
  /// shows, and one at rest takes its new value at once. When a changed coordinate is in motion, the changes that move one
  /// fold into an ease-out change, while the other changes keep going with their timing, a running spring keeps going
  /// with the glide stacked on it, and a spring that never settles folds too, as it can't overlap other changes.
  /// Otherwise, the changes keep going on the new path, as in `setPath(keyPath:to:)`. Without changes in flight, the path
  /// shows at once.
  ///
  /// A path that follows the layer's size, such as a shadow's, glides with the layer's frame through the
  /// `retargetPath(keyPath:to:)` that takes the path for a size.
  ///
  /// - Important: The key path must hold a `CGPath`, such as `shadowPath` or `CAShapeLayer`'s `path`. A key path that
  ///   holds another value asserts, and the layer is left alone.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - path: The path to set.
  @_spi(Private)
  func retargetPath(keyPath: String, to path: CGPath) {
    retargetPath(keyPath: keyPath, resizingFrom: { _ in nil }, to: { _ in path })
  }

  // MARK: - Paths Following the Layer's Size

  /// Animate a path of the layer that follows the layer's size additively, as `animatePath(keyPath:to:timing:)` does.
  ///
  /// The path is made for the layer's size, and the layer remembers the size, which tells a later resize apart from a
  /// change of the path's shape, so the `retargetPath(keyPath:to:)` that takes the path for a size moves the path with
  /// the layer's frame. A path set some other way has no size to tell a resize by, so its change counts as a change of
  /// its shape.
  ///
  /// - Important: The key path must hold a `CGPath`, such as `shadowPath` or `CAShapeLayer`'s `path`. A key path that
  ///   holds another value asserts, and the layer is left alone.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - timing: The animation timing.
  ///   - path: The path for a size. It's called with the layer's size, and after a resize with the size the current path
  ///     was made for, and the new width with the old height, too.
  @_spi(Private)
  func animatePath(keyPath: String, timing: AnimationTiming, to path: (CGSize) -> CGPath) {
    let pathSizes = PathSizes.of(self)
    let newPath = animatePath(keyPath: keyPath, timing: timing, resizingFrom: { pathSizes.size(forKeyPath: keyPath, of: $0) }, to: path)
    pathSizes.remember(newPath, size: bounds.size, forKeyPath: keyPath)
  }

  /// Set a path of the layer that follows the layer's size and retarget its changes in flight to it, so the path glides
  /// with the layer's frame, see `retargetFrame(to:)`.
  ///
  /// The change of the path's shape, of the layer's width and of its height are judged apart, each against the motion of
  /// the same part of the changes in flight.
  ///
  /// - The width and the height are judged as the frame's size is, axis by axis, in `retargetFrame(to:)`: one that
  ///   changed and is in motion glides from where it shows, one that changed at rest takes its new value at once, and
  ///   the motion of one that didn't change keeps its timing.
  /// - The shape glides at the coordinates it changes that are in motion: the changes that move such a coordinate fold
  ///   their shape's motion into an ease-out change, and the other changes keep theirs with their timing.
  /// - A glide lands when the changes it folds would have. A running spring keeps going with the glides stacked on it,
  ///   and a spring that never settles folds whole, as it can't overlap other changes, unless only the shape glides while
  ///   the spring moves the size, which keeps going with the frame's size as the shape's change shows at once.
  ///
  /// The layer remembers the size it makes the path for, see `animatePath(keyPath:timing:to:)`. Without changes in
  /// flight, the path shows at once.
  ///
  /// - Important: The key path must hold a `CGPath`, such as `shadowPath` or `CAShapeLayer`'s `path`. A key path that
  ///   holds another value asserts, and the layer is left alone.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - path: The path for a size. It's called with the layer's size, and with changes in flight after a resize, with
  ///     the size the current path was made for, and the new width with the old height, too.
  @_spi(Private)
  func retargetPath(keyPath: String, to path: (CGSize) -> CGPath) {
    let pathSizes = PathSizes.of(self)
    let newPath = retargetPath(keyPath: keyPath, resizingFrom: { pathSizes.size(forKeyPath: keyPath, of: $0) }, to: path)
    pathSizes.remember(newPath, size: bounds.size, forKeyPath: keyPath)
  }
}

extension CALayer {

  /// Animate a path of the layer that follows its size additively, with the size the current path was made for, which
  /// tells the change of the path's shape apart from the changes of the width and the height, see
  /// `animatePath(keyPath:timing:to:)`.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - timing: The animation timing.
  ///   - oldSize: The size the current path, which it's given, was made for, or `nil` when it isn't known, which makes
  ///     the change all the shape's.
  ///   - path: The path for a size. It's called with the layer's size, and after a resize with the sizes between, see
  ///     `PathChanges.Resize`.
  /// - Returns: The path for the layer's size.
  @discardableResult
  func animatePath(keyPath: String, timing: AnimationTiming, resizingFrom oldSize: (_ currentPath: CGPath) -> CGSize?, to path: (CGSize) -> CGPath) -> CGPath {
    let size = bounds.size
    let newPath = path(size)
    switch modelPath(forKeyPath: keyPath) {
    case .path(let currentPath):
      let oldSize = oldSize(currentPath).flatMap { $0 == size ? nil : $0 }
      // a resize that a change of the shape cancels out leaves the path as it is, but it's still a change
      guard currentPath != newPath || oldSize != nil else {
        return newPath
      }
      let now = currentTime
      var changes = pathChanges(forKeyPath: keyPath, at: now)
      let currentPoints = PathPoints(currentPath)
      let points = PathPoints(newPath)
      let resize = oldSize.map { resizeOfPath(path, from: $0, to: size, current: currentPath, currentPoints: currentPoints, newPoints: points) }
      changes.record(from: currentPoints, to: points, resize: resize, timing: timing, at: now)
      showPath(newPath, points: points, forKeyPath: keyPath, changes: changes, at: now)
    case .noValue:
      showPathAtOnce(newPath, forKeyPath: keyPath)
    case .notAPath:
      break
    }
    return newPath
  }

  /// Set a path of the layer that follows its size and retarget its changes in flight to it, with the size the current
  /// path was made for, see `retargetPath(keyPath:to:)` and `animatePath(keyPath:timing:resizingFrom:to:)`.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - oldSize: The size the current path, which it's given, was made for, or `nil` when it isn't known, which makes
  ///     the change all the shape's.
  ///   - path: The path for a size. It's called with the layer's size, and with changes in flight after a resize, with
  ///     the sizes between, see `PathChanges.Resize`.
  /// - Returns: The path for the layer's size.
  @discardableResult
  func retargetPath(keyPath: String, resizingFrom oldSize: (_ currentPath: CGPath) -> CGSize?, to path: (CGSize) -> CGPath) -> CGPath {
    let size = bounds.size
    let newPath = path(size)
    switch modelPath(forKeyPath: keyPath) {
    case .path(let currentPath):
      let oldSize = oldSize(currentPath).flatMap { $0 == size ? nil : $0 }
      // a resize that a change of the shape cancels out leaves the path as it is, but the resize glides with the frame
      guard currentPath != newPath || oldSize != nil else {
        return newPath
      }
      let now = currentTime
      var changes = pathChanges(forKeyPath: keyPath, at: now)
      guard !changes.isEmpty else {
        showPathAtOnce(newPath, forKeyPath: keyPath)
        return newPath
      }
      let currentPoints = PathPoints(currentPath)
      let points = PathPoints(newPath)
      let resize = oldSize.map { resizeOfPath(path, from: $0, to: size, current: currentPath, currentPoints: currentPoints, newPoints: points) }
      changes.retarget(from: currentPoints, to: points, resize: resize, at: now)
      showPath(newPath, points: points, forKeyPath: keyPath, changes: changes, at: now)
    case .noValue:
      showPathAtOnce(newPath, forKeyPath: keyPath)
    case .notAPath:
      break
    }
    return newPath
  }
}

private extension CALayer {

  /// The path's changes in flight, kept on the animation that shows them.
  func pathChanges(forKeyPath keyPath: String, at now: TimeInterval) -> PathChanges {
    guard let box = animation(forKey: LayerKeyPath.objectiveC(keyPath))?.value(forKey: PathChangesBox.key) as? PathChangesBox else {
      return PathChanges()
    }
    var changes = box.changes
    changes.removeLandedChanges(at: now)
    return changes
  }

  /// Sets the model path, and shows it with the changes in flight.
  ///
  /// - Parameters:
  ///   - path: The path.
  ///   - points: The points of the path, when the caller has them already.
  ///   - keyPath: The key path of the path.
  ///   - changes: The changes in flight.
  ///   - now: The layer's current time.
  func showPath(_ path: CGPath, points: PathPoints?, forKeyPath keyPath: String, changes: PathChanges, at now: TimeInterval) {
    guard !changes.isEmpty else {
      showPathAtOnce(path, forKeyPath: keyPath)
      return
    }

    let points = points ?? PathPoints(path)
    guard changes.hasSameSegments(as: points), points.isFinite else {
      showPathAtOnce(path, forKeyPath: keyPath)
      return
    }

    let objectiveCKeyPath = LayerKeyPath.objectiveC(keyPath)
    let animation: CAPropertyAnimation
    if changes.changes.count == 1 {
      // one change is an animation between two paths, which Core Animation evaluates on every frame. it is a copy of the
      // change's own animation, since the changes stored on it hold that animation, which would then hold itself
      let change = changes.changes[0]
      let basicAnimation = change.animation.copy() as! CABasicAnimation // swiftlint:disable:this force_cast
      basicAnimation.keyPath = objectiveCKeyPath
      basicAnimation.fromValue = points.adding(change.offset).path
      basicAnimation.toValue = path
      basicAnimation.beginTime = change.beginTime
      animation = basicAnimation
    } else {
      // the keyframes come with key times only when a change begins or lands between evenly spread keyframes, as Core
      // Animation spreads keyframes without key times evenly
      let keyframes = changes.keyframes(adding: path, points: points, at: now)
      let keyframeAnimation = CAKeyframeAnimation(keyPath: objectiveCKeyPath)
      keyframeAnimation.values = keyframes.paths
      keyframeAnimation.keyTimes = keyframes.keyTimes
      keyframeAnimation.calculationMode = .linear
      keyframeAnimation.duration = keyframes.duration
      keyframeAnimation.fillMode = .both
      keyframeAnimation.beginTime = CAAnimation.beginTime(at: now)
      animation = keyframeAnimation
    }

    animation.setValue(PathChangesBox(changes), forKey: PathChangesBox.key)
    add(animation, forKey: objectiveCKeyPath)
    #if DEBUG
    WorkCounter.count(.animation)
    #endif
    setKeyPathValue(keyPath, path)
  }

  /// The points of a path that follows the layer's size at the sizes between the current path's and the new path's, see
  /// `PathChanges.Resize`.
  ///
  /// - Parameters:
  ///   - path: The path for a size.
  ///   - oldSize: The size the current path was made for.
  ///   - newSize: The size the new path is made for.
  ///   - current: The current path.
  ///   - currentPoints: The points of the current path.
  ///   - newPoints: The points of the new path.
  /// - Returns: The points, which reuse the points at hand where a size between gives a path that is at hand, so they
  ///   aren't read again: the current path's when only the size changed, as is usual, and the new path's or the points
  ///   at the old size when only one dimension changed.
  func resizeOfPath(_ path: (CGSize) -> CGPath, from oldSize: CGSize, to newSize: CGSize, current: CGPath, currentPoints: PathPoints, newPoints: PathPoints) -> PathChanges.Resize {
    let pathAtOldSize = path(oldSize)
    let atOldSize = pathAtOldSize == current ? currentPoints : PathPoints(pathAtOldSize)
    let atNewWidth: PathPoints
    if newSize.height == oldSize.height {
      atNewWidth = newPoints
    } else if newSize.width == oldSize.width {
      atNewWidth = atOldSize
    } else {
      atNewWidth = PathPoints(path(CGSize(width: newSize.width, height: oldSize.height)))
    }
    return PathChanges.Resize(atOldSize: atOldSize, atNewWidth: atNewWidth)
  }

  /// Sets the model path, and removes the animation of the changes in flight, so the path shows at once.
  func showPathAtOnce(_ path: CGPath, forKeyPath keyPath: String) {
    let objectiveCKeyPath = LayerKeyPath.objectiveC(keyPath)
    if animation(forKey: objectiveCKeyPath)?.value(forKey: PathChangesBox.key) is PathChangesBox {
      removeAnimation(forKey: objectiveCKeyPath)
    }
    setKeyPathValue(keyPath, path)
  }

  /// The model value at a key path, which should hold a path.
  func modelPath(forKeyPath keyPath: String) -> ModelPath {
    // a read through KVC costs a sizable share of setting a path, so the paths the framework animates, the shadow path
    // and a shape layer's path, are read directly
    switch keyPath {
    case "shadowPath":
      return shadowPath.map { .path($0) } ?? .noValue
    case "path":
      if let shapeLayer = self as? CAShapeLayer {
        return shapeLayer.path.map { .path($0) } ?? .noValue
      }
    default:
      break
    }

    guard let value = value(forKeyPath: keyPath) else {
      return .noValue
    }

    let object = value as AnyObject
    guard CFGetTypeID(object) == CGPath.typeID else {
      ComposeUI.assertFailure("expected a path at \"\(keyPath)\", got \(value)")
      return .notAPath
    }
    return .path(unsafeDowncast(object, to: CGPath.self))
  }
}

/// The model value at a key path that should hold a path.
private enum ModelPath {

  /// The key path holds a path.
  case path(CGPath)

  /// The key path holds no value, as a shape layer without a path.
  case noValue

  /// The key path holds a value that isn't a path.
  case notAPath
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

/// The sizes a layer's paths were made for, by the functions that take the path for a size, such as
/// `CALayer.animatePath(keyPath:timing:to:)`. An extension can't add stored properties to a layer, so they're kept on it
/// as an associated object.
private final class PathSizes {

  /// A path made for a size.
  private struct Entry {

    /// The key path of the path.
    let keyPath: String

    /// The path.
    var path: CGPath

    /// The size the path was made for.
    var size: CGSize
  }

  /// The key of the sizes on a layer, a stable address.
  private static let key = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

  /// The paths made for a size, one for each key path.
  private var entries: [Entry] = []

  /// The sizes of a layer's paths, kept on the layer from its first path made for a size.
  ///
  /// - Parameter layer: The layer.
  /// - Returns: The sizes.
  static func of(_ layer: CALayer) -> PathSizes {
    if let pathSizes = objc_getAssociatedObject(layer, key) as? PathSizes {
      return pathSizes
    }
    let pathSizes = PathSizes()
    objc_setAssociatedObject(layer, key, pathSizes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    return pathSizes
  }

  /// The size the current path at a key path was made for.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the path.
  ///   - currentPath: The current path.
  /// - Returns: The size, or `nil` when the current path wasn't made for a size here, as when it was set some other way.
  func size(forKeyPath keyPath: String, of currentPath: CGPath) -> CGSize? {
    guard let entry = entries.first(where: { $0.keyPath == keyPath }), entry.path == currentPath else {
      return nil
    }
    return entry.size
  }

  /// Remembers the size a path was made for.
  ///
  /// - Parameters:
  ///   - path: The path.
  ///   - size: The size the path was made for.
  ///   - keyPath: The key path of the path.
  func remember(_ path: CGPath, size: CGSize, forKeyPath keyPath: String) {
    if let index = entries.firstIndex(where: { $0.keyPath == keyPath }) {
      entries[index].path = path
      entries[index].size = size
    } else {
      entries.append(Entry(keyPath: keyPath, path: path, size: size))
    }
  }
}
