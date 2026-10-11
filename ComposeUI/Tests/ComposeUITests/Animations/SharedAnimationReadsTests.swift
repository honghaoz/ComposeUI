//
//  SharedAnimationReadsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/10/26.
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

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class SharedAnimationReadsTests: XCTestCase {

  func test_lookUp_differentKeyPaths_shareOneRead() throws {
    // given: a layer whose position animates directly and through its x component, whose background color animates in a
    // group, with an opacity animation and an animation without a key path
    let layer = CALayer()
    layer.add(animation("position"), forKey: "move")
    layer.add(animation("position.x"), forKey: "move-x")
    layer.add(group(of: [animation("backgroundColor")]), forKey: "group-tint")
    layer.add(animation("opacity"), forKey: "fade")
    layer.add(CABasicAnimation(), forKey: "no-key-path")

    // when: looking up the animations of several key paths in updates that share the reads
    var positionAnimations: [(key: String, animation: KeyPathAnimation)] = []
    var colorAnimations: [(key: String, animation: KeyPathAnimation)] = []
    var opacityAnimations: [(key: String, animation: KeyPathAnimation)] = []
    var hasCornerRadiusAnimations = true
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        positionAnimations = layer.animationSequence(forKeyPath: "position").map { Array($0) } ?? []
        colorAnimations = layer.animationSequence(forKeyPath: "backgroundColor").map { Array($0) } ?? []
        opacityAnimations = layer.animationSequence(forKeyPath: "opacity").map { Array($0) } ?? []
        hasCornerRadiusAnimations = layer.animationSequence(forKeyPath: "cornerRadius") != nil
      }
    }

    // then: the layer's animation keys are read once, and each lookup finds its key path's animations in the read
    expect(counts.animationKeysReads) == 1
    expect(positionAnimations.map(\.key)) == ["move", "move-x"]
    expect(positionAnimations.map { kind(of: $0.animation) }) == ["direct", "indirect"]
    expect(colorAnimations.map(\.key)) == ["group-tint"]
    expect(colorAnimations.map { kind(of: $0.animation) }) == ["indirect"]
    expect(opacityAnimations.map(\.key)) == ["fade"]
    expect(hasCornerRadiusAnimations) == false
  }

  func test_lookUp_layerWithoutAnimations_readsOnce() {
    // given: a layer without animations
    let layer = CALayer()

    // when: looking up the animations of two key paths in updates that share the reads
    var hasOpacityAnimations = true
    var hasPositionAnimations = true
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        hasOpacityAnimations = layer.animationSequence(forKeyPath: "opacity") != nil
        hasPositionAnimations = layer.animationSequence(forKeyPath: "position") != nil
      }
    }

    // then: the keys are read once, and neither key path has animations
    expect(counts.animationKeysReads) == 1
    expect(hasOpacityAnimations) == false
    expect(hasPositionAnimations) == false
  }

  func test_lookUp_keyPathWithAnimationsFoundBefore_readsTheLayer() throws {
    // given: a layer with an opacity animation
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")

    // when: looking up the opacity's animations, replacing the animation, and looking them up again
    var firstKeys: [String] = []
    var secondKeys: [String] = []
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        firstKeys = layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? []
        layer.removeAnimation(forKey: "fade")
        layer.add(animation("opacity"), forKey: "fade-again")
        secondKeys = layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? []
      }
    }

    // then: the second lookup reads the layer, since the key path's animations may have changed, and finds the new one
    expect(counts.animationKeysReads) == 2
    expect(firstKeys) == ["fade"]
    expect(secondKeys) == ["fade-again"]
  }

  func test_lookUp_relatedKeyPath_readsTheLayer() throws {
    // given: a layer whose position and bounds size animate, with an opacity animation
    let layer = CALayer()
    layer.add(animation("position"), forKey: "move")
    layer.add(animation("bounds.size"), forKey: "resize")
    layer.add(animation("opacity"), forKey: "fade")

    // when: looking up the position, removing its animation, and looking up its x component, then looking up the size,
    // removing its animation, and looking up the bounds, which the size is a component of, and then the opacity
    var positionXKeys: [String]?
    var boundsKeys: [String]?
    var opacityKeys: [String]?
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        _ = layer.animationSequence(forKeyPath: "position")
        layer.removeAnimation(forKey: "move")
        positionXKeys = layer.animationSequence(forKeyPath: "position.x").map { $0.map(\.key) }

        _ = layer.animationSequence(forKeyPath: "bounds.size")
        layer.removeAnimation(forKey: "resize")
        boundsKeys = layer.animationSequence(forKeyPath: "bounds").map { $0.map(\.key) }

        opacityKeys = layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) }
      }
    }

    // then: the lookups of the related key paths read the layer and don't find the removed animations, while the
    // opacity's lookup uses the read
    expect(counts.animationKeysReads) == 3
    expect(positionXKeys) == nil
    expect(boundsKeys) == nil
    expect(opacityKeys) == ["fade"]
  }

  func test_lookUp_animationAddedAfterTheRead_readsTheLayerForItsKeyPath() throws {
    // given: a layer with an opacity animation
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")

    // when: looking up the opacity's animations, then animating the corner radius and looking up its animations
    var cornerRadiusKeys: [String] = []
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        _ = layer.animationSequence(forKeyPath: "opacity")
        layer.animate(keyPath: "cornerRadius", to: CGFloat(8), timing: .easeInEaseOut(duration: 1))
        cornerRadiusKeys = layer.animationSequence(forKeyPath: "cornerRadius").map { $0.map(\.key) } ?? []
      }
    }

    // then: the corner radius's lookup reads the layer, since its animation was added after the read, and finds it
    expect(counts.animationKeysReads) == 2
    expect(cornerRadiusKeys) == ["cornerRadius"]
  }

  func test_lookUp_animationOfAKeyPathFoundBefore_keepsTheReadForOthers() throws {
    // given: a layer with opacity and position animations, and another layer
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")
    layer.add(animation("position"), forKey: "move")
    let otherLayer = CALayer()

    // when: looking up the opacity's animations and animating the opacity, and animating the other layer's corner radius,
    // then looking up the position's and the corner radius's animations
    var positionKeys: [String] = []
    var hasCornerRadiusAnimations = true
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        _ = layer.animationSequence(forKeyPath: "opacity")
        layer.animate(keyPath: "opacity", to: CGFloat(0.5), timing: .easeInEaseOut(duration: 1))
        otherLayer.animate(keyPath: "cornerRadius", to: CGFloat(8), timing: .easeInEaseOut(duration: 1))
        positionKeys = layer.animationSequence(forKeyPath: "position").map { $0.map(\.key) } ?? []
        hasCornerRadiusAnimations = layer.animationSequence(forKeyPath: "cornerRadius") != nil
      }
    }

    // then: both lookups use the read, as the animations were of a key path found before and of another layer
    expect(counts.animationKeysReads) == 1
    expect(positionKeys) == ["move"]
    expect(hasCornerRadiusAnimations) == false
  }

  func test_lookUp_keyPathWithoutAnimations_keepsTheReadForIt() throws {
    // given: a layer with an opacity animation
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")

    // when: looking up the corner radius's animations twice
    var lookups: [Bool] = []
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        lookups.append(layer.animationSequence(forKeyPath: "cornerRadius") != nil)
        lookups.append(layer.animationSequence(forKeyPath: "cornerRadius") != nil)
      }
    }

    // then: both lookups use the read, since a lookup that finds no animations leaves its caller none to change
    expect(counts.animationKeysReads) == 1
    expect(lookups) == [false, false]
  }

  func test_startSharing_beforeOrOutsideTheUpdates_lookupsReadTheLayer() throws {
    // given: a layer with an opacity animation
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")

    // when: looking up the opacity's animations in updates before a property update starts sharing, with one lookup in
    // unshared code, and after starting to share outside the updates
    var keys: [[String]] = []
    let counts = WorkCounter.counting {
      SharedAnimationReads.performUpdates {
        keys.append(layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? [])
        SharedAnimationReads.performUnshared {
          keys.append(layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? [])
        }
      }
      SharedAnimationReads.startSharing(for: .layer(layer))
      keys.append(layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? [])
      keys.append(layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? [])
    }

    // then: each lookup reads the layer
    expect(counts.animationKeysReads) == 4
    expect(keys) == [["fade"], ["fade"], ["fade"], ["fade"]]
  }

  func test_startSharing_firstLayerWins_andAViewWithoutALayerDoesntStart() throws {
    // given: two layers with an opacity animation each
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")
    let otherLayer = CALayer()
    otherLayer.add(animation("opacity"), forKey: "other-fade")

    // when: in updates, starting to share for a view without a layer on macOS, then for the layer, then for the other
    // layer, then looking up the layer's opacity and corner radius animations and the other layer's opacity animations
    var keys: [[String]] = []
    let counts = WorkCounter.counting {
      SharedAnimationReads.performUpdates {
        #if canImport(AppKit)
        SharedAnimationReads.startSharing(for: .view(NSView()))
        #endif
        SharedAnimationReads.startSharing(for: .layer(layer))
        SharedAnimationReads.startSharing(for: .layer(otherLayer))
        keys.append(layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? [])
        keys.append(layer.animationSequence(forKeyPath: "cornerRadius").map { $0.map(\.key) } ?? [])
        keys.append(otherLayer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? [])
      }
    }

    // then: the layer's lookups share a read, while the other layer's lookup reads the other layer
    expect(counts.animationKeysReads) == 2
    expect(keys) == [["fade"], [], ["other-fade"]]
  }

  func test_lookUp_animationAddedBeforeTheRead_isInTheRead() throws {
    // given: a layer with an opacity animation
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")

    // when: animating the corner radius before looking up animations, then looking up the corner radius's and the
    // opacity's animations
    var cornerRadiusKeys: [String] = []
    var opacityKeys: [String] = []
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        layer.animate(keyPath: "cornerRadius", to: CGFloat(8), timing: .easeInEaseOut(duration: 1))
        cornerRadiusKeys = layer.animationSequence(forKeyPath: "cornerRadius").map { $0.map(\.key) } ?? []
        opacityKeys = layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? []
      }
    }

    // then: the read has the added animation, so both lookups use it
    expect(counts.animationKeysReads) == 1
    expect(cornerRadiusKeys) == ["cornerRadius"]
    expect(opacityKeys) == ["fade"]
  }

  func test_lookUp_otherLayersAndNestedUpdates_readTheirLayers() throws {
    // given: two layers with an opacity and a position animation each
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")
    layer.add(animation("position"), forKey: "move")
    let otherLayer = CALayer()
    otherLayer.add(animation("opacity"), forKey: "other-fade")
    otherLayer.add(animation("position"), forKey: "other-move")

    // when: looking up the layer's opacity animations in updates that share its reads, then the other layer's, then the
    // other layer's in updates nested in these that would share its reads, then the layer's position animations
    var otherOpacityKeys: [String] = []
    var nestedKeys: [String] = []
    var positionKeys: [String] = []
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        _ = layer.animationSequence(forKeyPath: "opacity")
        otherOpacityKeys = otherLayer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? []
        sharingReads(of: otherLayer) {
          nestedKeys = otherLayer.animationSequence(forKeyPath: "position").map { $0.map(\.key) } ?? []
        }
        positionKeys = layer.animationSequence(forKeyPath: "position").map { $0.map(\.key) } ?? []
      }
    }

    // then: the other layer's lookups read the other layer, also in the nested updates, while the layer's lookups share
    // a read
    expect(counts.animationKeysReads) == 3
    expect(otherOpacityKeys) == ["other-fade"]
    expect(nestedKeys) == ["other-move"]
    expect(positionKeys) == ["move"]
  }

  func test_performUnshared_readsTheLayerAndDropsTheRead() throws {
    // given: a layer with an opacity animation
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")

    // when: looking up the opacity's animations, then, in code that runs unshared, looking up the position's and
    // the corner radius's animations, the latter nested in more unshared code, and adding a position animation, then looking up
    // the position's and the opacity's animations after it
    var unsharedPositionKeys: [String]?
    var nestedUnsharedCornerRadiusKeys: [String]?
    var positionKeys: [String] = []
    var opacityKeys: [String] = []
    let counts = WorkCounter.counting {
      sharingReads(of: layer) {
        _ = layer.animationSequence(forKeyPath: "opacity")
        let result = SharedAnimationReads.performUnshared {
          unsharedPositionKeys = layer.animationSequence(forKeyPath: "position").map { $0.map(\.key) }
          SharedAnimationReads.performUnshared {
            nestedUnsharedCornerRadiusKeys = layer.animationSequence(forKeyPath: "cornerRadius").map { $0.map(\.key) }
          }
          layer.add(animation("position"), forKey: "move")
          return 42
        }
        expect(result) == 42
        positionKeys = layer.animationSequence(forKeyPath: "position").map { $0.map(\.key) } ?? []
        opacityKeys = layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? []
      }
    }

    // then: the unshared lookups read the layer, and the lookups after the code share a new read, which has the code's
    // animation, and for which the opacity's animations haven't changed
    expect(counts.animationKeysReads) == 4
    expect(unsharedPositionKeys) == nil
    expect(nestedUnsharedCornerRadiusKeys) == nil
    expect(positionKeys) == ["move"]
    expect(opacityKeys) == ["fade"]
  }

  func test_performUnshared_outsideTheUpdates_runsTheBody() {
    // given: a layer with an opacity animation
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")

    // when: looking up the opacity's animations twice unshared, outside the updates
    var keys: [[String]] = []
    let counts = WorkCounter.counting {
      let result = SharedAnimationReads.performUnshared {
        keys.append(layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? [])
        keys.append(layer.animationSequence(forKeyPath: "opacity").map { $0.map(\.key) } ?? [])
        return "done"
      }
      expect(result) == "done"
    }

    // then: each lookup reads the layer
    expect(counts.animationKeysReads) == 2
    expect(keys) == [["fade"], ["fade"]]
  }

  func test_performUpdates_dropsTheReadAfterwards() throws {
    // given: a layer with an opacity animation, whose animations were looked up in updates that share the reads
    let layer = CALayer()
    layer.add(animation("opacity"), forKey: "fade")
    sharingReads(of: layer) {
      _ = layer.animationSequence(forKeyPath: "opacity")
    }

    // when: adding a position animation, then looking up the position's animations outside the updates, and in new updates
    layer.add(animation("position"), forKey: "move")
    var outsideKeys: [String] = []
    var updatesKeys: [String] = []
    let counts = WorkCounter.counting {
      outsideKeys = layer.animationSequence(forKeyPath: "position").map { $0.map(\.key) } ?? []
      sharingReads(of: layer) {
        updatesKeys = layer.animationSequence(forKeyPath: "position").map { $0.map(\.key) } ?? []
      }
    }

    // then: both lookups read the layer and find the new animation
    expect(counts.animationKeysReads) == 2
    expect(outsideKeys) == ["move"]
    expect(updatesKeys) == ["move"]
  }

  // MARK: - Helpers

  /// Runs the body in updates that share the reads of the layer's animations, as from the first property update on.
  private func sharingReads(of layer: CALayer, _ body: () -> Void) {
    SharedAnimationReads.performUpdates {
      SharedAnimationReads.startSharing(for: .layer(layer))
      body()
    }
  }

  /// A basic animation of the key path that runs for a minute.
  private func animation(_ keyPath: String) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: keyPath)
    animation.duration = 60
    return animation
  }

  /// A group of the animations that runs for a minute.
  private func group(of animations: [CAAnimation]) -> CAAnimationGroup {
    let group = CAAnimationGroup()
    group.animations = animations
    group.duration = 60
    return group
  }

  /// The kind of a key path animation, as a name.
  private func kind(of animation: KeyPathAnimation) -> String {
    switch animation {
    case .direct:
      return "direct"
    case .indirect:
      return "indirect"
    }
  }
}
