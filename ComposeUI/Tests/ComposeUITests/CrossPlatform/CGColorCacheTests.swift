//
//  CGColorCacheTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/26.
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

import ChouTiTest

@testable import ComposeUI

final class CGColorCacheTests: XCTestCase {

  // MARK: - AppKit

  #if canImport(AppKit)

  func test_cgColor_componentBasedColor_keepsItsCGColor() {
    // given: a component-based color in a tagged pointer, whose components are multiples of 1/255, and whose CGColor
    // AppKit makes again for each read, so that only the cache gives the same CGColor twice
    let color = NSColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 1)
    expect(color.cgColor) !== color.cgColor

    // when: getting its CGColor twice
    let cgColor = CGColorCache.cgColor(of: color)
    let secondCGColor = CGColorCache.cgColor(of: color)

    // then: the cache keeps the color's CGColor and gives it again
    expect(cgColor) == color.cgColor
    expect(secondCGColor) === cgColor
    expect(CGColorCache.keptCGColorForTesting(of: color)) === cgColor
  }

  func test_cgColor_catalogColor_followsTheAppearance() throws {
    // given: a system color and a color of a dynamic provider, whose CGColors follow the appearance
    let colors = [
      NSColor.labelColor,
      NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .white : .black
      },
    ]
    let aqua = try NSAppearance(named: .aqua).unwrap()
    let darkAqua = try NSAppearance(named: .darkAqua).unwrap()

    for color in colors {
      // when: getting the color's CGColor in the light and in the dark appearance
      var lightCGColor: CGColor?
      aqua.performAsCurrentDrawingAppearance {
        lightCGColor = CGColorCache.cgColor(of: color)
      }
      var darkCGColor: CGColor?
      darkAqua.performAsCurrentDrawingAppearance {
        darkCGColor = CGColorCache.cgColor(of: color)
      }

      // then: each is the color's CGColor in its appearance, and the cache keeps neither
      aqua.performAsCurrentDrawingAppearance {
        expect(lightCGColor) == color.cgColor
      }
      darkAqua.performAsCurrentDrawingAppearance {
        expect(darkCGColor) == color.cgColor
      }
      expect(lightCGColor) != darkCGColor
      expect(CGColorCache.keptCGColorForTesting(of: color)) == nil
    }
  }

  func test_cgColor_patternColor_isNotKept() {
    // given: a pattern color, whose CGColor follows its image
    let color = NSColor(patternImage: NSImage(size: CGSize(width: 2, height: 2), flipped: false) { _ in true })

    // when: getting its CGColor
    let cgColor = CGColorCache.cgColor(of: color)

    // then: the CGColor draws the pattern, and the cache doesn't keep it
    expect(cgColor.pattern) != nil
    expect(CGColorCache.keptCGColorForTesting(of: color)) == nil
  }

  func test_cgColor_offTheMainThread_isNotKept() {
    // given: a component-based color that the main thread hasn't read
    let color = NSColor(srgbRed: 0.17, green: 0.29, blue: 0.83, alpha: 1)

    // when: getting its CGColor on another thread
    let cgColor = onNewThread {
      CGColorCache.cgColor(of: color)
    }

    // then: it's the color's CGColor, and the cache doesn't keep it
    expect(cgColor) == color.cgColor
    expect(CGColorCache.keptCGColorForTesting(of: color)) == nil
  }

  func test_cgColor_colorOfAKeptColorsEntry_replacesTheKeptColor() throws {
    // given: a kept color, and another color of the same entry
    let color = NSColor(srgbRed: 0.4, green: 0.2, blue: 0.6, alpha: 1)
    let cgColor = CGColorCache.cgColor(of: color)
    let otherColor = try Self.color(ofTheEntryOf: color).unwrap()

    // when: getting the other color's CGColor
    let otherCGColor = CGColorCache.cgColor(of: otherColor)

    // then: the cache keeps the other color in place of the first
    expect(cgColor) == color.cgColor
    expect(otherCGColor) == otherColor.cgColor
    expect(CGColorCache.keptCGColorForTesting(of: otherColor)) === otherCGColor
    expect(CGColorCache.keptCGColorForTesting(of: color)) == nil

    // when: getting the first color's CGColor again
    let newCGColor = CGColorCache.cgColor(of: color)

    // then: it's the first color's own CGColor, kept again
    expect(newCGColor) == color.cgColor
    expect(CGColorCache.keptCGColorForTesting(of: color)) === newCGColor
    expect(CGColorCache.keptCGColorForTesting(of: otherColor)) == nil
  }

  func test_cgColor_keepsTheColor_untilAnotherColorTakesItsEntry() throws {
    // given: a component-based color in an object of its own, read once by an owner that releases it
    weak var weakColor: NSColor?
    var otherColor: NSColor?
    autoreleasepool {
      let color = NSColor(srgbRed: 0.123456789, green: 0.3456789, blue: 0.56789, alpha: 0.987654)
      weakColor = color
      otherColor = Self.color(ofTheEntryOf: color)
      _ = CGColorCache.cgColor(of: color)
    }

    // then: the cache keeps the color, so that no other color takes its address while its entry matches it
    expect(weakColor) != nil

    // when: another color takes its entry
    _ = try CGColorCache.cgColor(of: otherColor.unwrap())

    // then: the cache releases the color
    expect(weakColor) == nil
  }

  /// Returns a component-based color other than the given one, of the same entry.
  private static func color(ofTheEntryOf color: NSColor) -> NSColor? {
    let index = CGColorCache.entryIndexForTesting(of: color)
    // the candidates' components are multiples of 1/255, so that each candidate is in a tagged pointer, whose bits
    // differ for each candidate, where objects made one after another could take the same address each time
    for red in 0 ... 255 {
      for green in 0 ... 255 {
        let candidate = NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: 0.8, alpha: 1)
        if candidate !== color, CGColorCache.entryIndexForTesting(of: candidate) == index {
          return candidate
        }
      }
    }
    return nil
  }

  #endif

  // MARK: - UIKit

  #if canImport(UIKit)

  func test_cgColor_isTheColorsCGColor() {
    // given: a color, and a color that follows the trait collection
    let color = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
    let dynamicColor = UIColor { traits in
      traits.userInterfaceStyle == .dark ? .white : .black
    }
    let dark = UITraitCollection(userInterfaceStyle: .dark)

    // then: the cache passes on the color's CGColor, and the dynamic color's in the current trait collection
    expect(CGColorCache.cgColor(of: color)) == color.cgColor
    dark.performAsCurrent {
      expect(CGColorCache.cgColor(of: dynamicColor)) == dynamicColor.resolvedColor(with: dark).cgColor
    }
  }

  #endif
}
