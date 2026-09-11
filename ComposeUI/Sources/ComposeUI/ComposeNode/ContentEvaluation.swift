//
//  ContentEvaluation.swift
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

/// An object that manages content evaluation. 
/// It it used to share the evaluated content between node copies and nested ComposeViews.
final class ContentEvaluation {
  
  /// A wrapper for a content closure.
  final class Provider<Value> {
    
    /// The content closure.
    fileprivate let make: () -> Value
    
    /// Creates a provider for a content closure, without evaluating it.
    ///
    /// - Parameter make: The closure to make a content.
    init(make: @escaping () -> Value) {
      self.make = make
    }
  }
  
  /// A lazy value wrapper that resolves provider's content on first access.
  final class LazyValue<Value> {
    
    /// The resolved content.
    private(set) lazy var value: Value = provider.make()
    
    /// The provider that makes the content.
    private let provider: Provider<Value>
    
    /// Creates a lazy value for a provider.
    ///
    /// - Parameter provider: The provider that makes the content.
    init(provider: Provider<Value>) {
      self.provider = provider
    }
  }
  
  /// The map of the lazy values by the provider's identifier.
  private var values: [ObjectIdentifier: AnyObject] = [:]
  
  init() {}

  /// Returns the a lazy value for the provider's content.
  ///
  /// - Parameter provider: The provider shared by node copies that should use the same content.
  /// - Returns: The existing or newly created lazy value, retained for this evaluation's lifetime.
  func lazyValue<Value>(for provider: Provider<Value>) -> LazyValue<Value> {
    let key = ObjectIdentifier(provider)
    if let value = values[key] as? LazyValue<Value> {
      return value
    } else {
      let value = LazyValue(provider: provider)
      values[key] = value
      return value
    }
  }
}
