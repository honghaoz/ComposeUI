//
//  TextDefaultsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/20/26.
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

@testable import ComposeUI

class TextDefaultsTests: XCTestCase {

  func test_fontAndTextColor_areALabels() {
    // then: the font is the system font of a label's size, both outside of layout and in a layout, and the text color
    // is the label color
    #if canImport(AppKit)
    let labelFont = Font.systemFont(ofSize: NSFont.systemFontSize)
    expect(TextDefaults.textColor) == ThemedColor(light: .labelColor, dark: .labelColor)
    #endif
    #if os(tvOS)
    let labelFont = Font.systemFont(ofSize: 20)
    #elseif canImport(UIKit)
    let labelFont = Font.systemFont(ofSize: Font.labelFontSize)
    #endif
    #if canImport(UIKit)
    expect(TextDefaults.textColor) == ThemedColor(light: .label, dark: .label)
    #endif
    expect(TextDefaults.font) == labelFont
    expect(TextDefaults.font(in: ComposeNodeLayoutContext(scaleFactor: 2))) == labelFont
  }

  #if canImport(UIKit)
  func test_fontCache_keepsTheFontOfEachBoldTextSetting() {
    // given: a font cache, and a regular and a semibold font, as the system font is with Bold Text off and on
    let cache = TextDefaults.FontCache()
    let regular = Font.systemFont(ofSize: 17, weight: .regular)
    let semibold = Font.systemFont(ofSize: 17, weight: .semibold)

    // when: getting the font with Bold Text off
    let font = cache.font(isBoldTextEnabled: false) { regular }

    // then: it's the font made for the setting
    expect(font) == regular

    // when: getting the font with Bold Text still off, from a block that makes another font
    let sameSettingFont = cache.font(isBoldTextEnabled: false) { semibold }

    // then: it's the font made before
    expect(sameSettingFont) == regular

    // when: Bold Text turns on, stays on, and turns off again
    let boldTextFont = cache.font(isBoldTextEnabled: true) { semibold }
    let stillBoldTextFont = cache.font(isBoldTextEnabled: true) { regular }
    let offAgainFont = cache.font(isBoldTextEnabled: false) { regular }

    // then: each change of the setting makes the font for it, which the cache keeps while the setting stays
    expect(boldTextFont) == semibold
    expect(stillBoldTextFont) == semibold
    expect(offAgainFont) == regular
  }

  func test_fontCache_offTheMainThread_makesTheFontWithoutKeepingIt() {
    // given: a font cache, a regular and a semibold font, and a Bold Text setting that records its reads
    let cache = TextDefaults.FontCache()
    let regular = Font.systemFont(ofSize: 17, weight: .regular)
    let semibold = Font.systemFont(ofSize: 17, weight: .semibold)
    var didReadTheSetting = false
    func readTheSetting() -> Bool {
      didReadTheSetting = true
      return false
    }

    // when: getting the font off the main thread
    var font: Font?
    let didGet = expectation(description: "got the font off the main thread")
    DispatchQueue.global().async {
      expect(Thread.isMainThread) == false
      font = cache.font(isBoldTextEnabled: readTheSetting()) { regular }
      didGet.fulfill()
    }
    wait(for: [didGet], timeout: 5)

    // then: it's the font made for the lookup, without reading the setting, which UIKit isolates to the main actor, and
    // the cache didn't keep it for the main thread
    expect(font) == regular
    expect(didReadTheSetting) == false
    expect(cache.font(isBoldTextEnabled: false) { semibold }) == semibold
  }

  func test_fontCache_inPass_readsTheSettingOncePerPass() {
    // given: a font cache, a regular and a semibold font, and a Bold Text setting that counts its reads
    let cache = TextDefaults.FontCache()
    let regular = Font.systemFont(ofSize: 17, weight: .regular)
    let semibold = Font.systemFont(ofSize: 17, weight: .semibold)
    var isBoldTextEnabled = false
    var readCount = 0
    func readTheSetting() -> Bool {
      readCount += 1
      return isBoldTextEnabled
    }

    // when: getting the font twice in a layout pass, with Bold Text turning on between the lookups
    let font = cache.font(inPass: 1, isBoldTextEnabled: readTheSetting()) { regular }
    isBoldTextEnabled = true
    let samePassFont = cache.font(inPass: 1, isBoldTextEnabled: readTheSetting()) { semibold }

    // then: the pass reads the setting once, and its lookups share the font made for that read
    expect(readCount) == 1
    expect(font) == regular
    expect(samePassFont) == regular

    // when: getting the font in the next pass
    let nextPassFont = cache.font(inPass: 2, isBoldTextEnabled: readTheSetting()) { semibold }

    // then: the next pass reads the setting again, and gets the font for it
    expect(readCount) == 2
    expect(nextPassFont) == semibold
  }

  func test_fontCache_inPass_offTheMainThread_makesTheFontWithoutReadingTheSetting() {
    // given: a font cache that keeps a regular font from a layout pass, and a Bold Text setting that counts its reads
    let cache = TextDefaults.FontCache()
    let regular = Font.systemFont(ofSize: 17, weight: .regular)
    let semibold = Font.systemFont(ofSize: 17, weight: .semibold)
    _ = cache.font(inPass: 1, isBoldTextEnabled: false) { regular }
    var readCount = 0
    func readTheSetting() -> Bool {
      readCount += 1
      return false
    }

    // when: getting the font in the next pass off the main thread
    var font: Font?
    let didGet = expectation(description: "got the font off the main thread")
    DispatchQueue.global().async {
      expect(Thread.isMainThread) == false
      font = cache.font(inPass: 2, isBoldTextEnabled: readTheSetting()) { semibold }
      didGet.fulfill()
    }
    wait(for: [didGet], timeout: 5)

    // then: it's the font made for the lookup, without reading the setting, which UIKit isolates to the main actor
    expect(font) == semibold
    expect(readCount) == 0

    // when: getting the font in that pass on the main thread
    let mainThreadFont = cache.font(inPass: 2, isBoldTextEnabled: readTheSetting()) { semibold }

    // then: the lookup reads the setting, since the lookup off the main thread didn't record the pass, and gets the
    // font kept for the setting
    expect(readCount) == 1
    expect(mainThreadFont) == regular
  }
  #endif
}
