//
//  ContentEvaluationTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/8/26.
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

class ContentEvaluationTests: XCTestCase {

  func test_lazyValue_resolvesProviderOnce() {
    // given: a provider whose output depends on mutable configuration
    var color = Color.red
    var providerCalls = 0
    let provider = ContentEvaluation.Provider {
      providerCalls += 1
      let layer = CALayer()
      layer.backgroundColor = color.cgColor
      return layer
    }
    let evaluation = ContentEvaluation()

    // when: selecting the same provider before its value is needed
    let first = evaluation.lazyValue(for: provider)
    let second = evaluation.lazyValue(for: provider)

    // then: selection shares one lazy value without executing the provider
    expect(first) === second
    expect(providerCalls) == 0

    // when: the value is first accessed after configuration changes
    color = .blue
    let layer = first.value

    // then: resolution uses the configuration at first access
    expect(layer.backgroundColor) == Color.blue.cgColor
    expect(providerCalls) == 1

    // when: accessing the value again after another change
    color = .green
    let retainedLayer = second.value

    // then: the evaluation preserves its existing result
    expect(retainedLayer) === layer
    expect(retainedLayer.backgroundColor) == Color.blue.cgColor
    expect(providerCalls) == 1
  }

  func test_separateEvaluations_keepIndependentValues() {
    // given: a provider reused across independent content evaluations
    var color = Color.red
    let provider = ContentEvaluation.Provider {
      let layer = CALayer()
      layer.backgroundColor = color.cgColor
      return layer
    }
    let first = ContentEvaluation()
    let second = ContentEvaluation()
    let firstLayer = first.lazyValue(for: provider).value

    // when: another evaluation resolves the same provider with new configuration
    color = .blue
    let secondLayer = second.lazyValue(for: provider).value

    // then: returning to the first evaluation retrieves its original content
    expect(firstLayer) !== secondLayer
    expect(first.lazyValue(for: provider).value) === firstLayer
    expect(firstLayer.backgroundColor) == Color.red.cgColor
    expect(secondLayer.backgroundColor) == Color.blue.cgColor
  }

  func test_providers_determineTheirValueTypes() {
    // given: separate providers with matching and different value types
    let red = ContentEvaluation.Provider { Color.red.cgColor }
    let blue = ContentEvaluation.Provider { Color.blue.cgColor }
    let frame = ContentEvaluation.Provider { CGRect(x: 1, y: 2, width: 30, height: 40) }
    let evaluation = ContentEvaluation()

    // when: all providers use the same evaluation
    let redValue = evaluation.lazyValue(for: red)
    let blueValue = evaluation.lazyValue(for: blue)
    let frameValue = evaluation.lazyValue(for: frame)

    // then: provider identity and type keep the values independent
    expect(redValue) !== blueValue
    expect(redValue.value) == Color.red.cgColor
    expect(blueValue.value) == Color.blue.cgColor
    expect(frameValue.value) == CGRect(x: 1, y: 2, width: 30, height: 40)
    expect(evaluation.lazyValue(for: frame)) === frameValue
  }

  func test_optionalNil_isAResolvedValue() {
    // given: a provider that initially returns no value
    var number: Int?
    var providerCalls = 0
    let provider = ContentEvaluation.Provider {
      providerCalls += 1
      return number
    }
    let evaluation = ContentEvaluation()
    let value = evaluation.lazyValue(for: provider)

    // when: nil is resolved before the supplied value changes
    expect(value.value) == nil
    number = 10

    // then: nil remains cached instead of invoking the provider again
    expect(evaluation.lazyValue(for: provider).value) == nil
    expect(providerCalls) == 1

    // when: a new evaluation resolves the same provider
    let refreshed = ContentEvaluation().lazyValue(for: provider)

    // then: the new evaluation observes the updated configuration
    expect(refreshed.value) == 10
    expect(providerCalls) == 2
  }

  func test_lazyValue_retainsProviderButNotEvaluation() {
    // given: an ordinary object whose lifetime is independent of core animation transactions
    weak var weakEvaluation: ContentEvaluation?
    weak var weakProvider: ContentEvaluation.Provider<NSObject>?
    weak var weakValue: NSObject?
    var retainedValue: ContentEvaluation.LazyValue<NSObject>?
    do {
      let evaluation = ContentEvaluation()
      let provider = ContentEvaluation.Provider { NSObject() }
      weakEvaluation = evaluation
      weakProvider = provider

      // when: only the selected lazy value is retained
      retainedValue = evaluation.lazyValue(for: provider)
      weakValue = retainedValue?.value
    }

    // then: the value preserves its provider and result without retaining the evaluation
    expect(weakEvaluation) == nil
    expect(weakProvider != nil) == true
    expect(weakValue != nil) == true
    expect(retainedValue?.value) === weakValue

    // when: the last lazy-value reference is released
    retainedValue = nil

    // then: the provider and resolved result are released together
    expect(weakProvider) == nil
    expect(weakValue) == nil
  }
}
