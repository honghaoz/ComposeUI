//
//  MemoryAddressString.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/19/25.
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

import Foundation

/// Get the object's raw pointer.
///
/// Example:
/// ```swift
/// let pointer = rawPointer(object)
/// ```
///
/// - Parameter object: An object.
/// - Returns Raw pointer.
@inlinable
@inline(__always)
func rawPointer(_ object: AnyObject) -> UnsafeMutableRawPointer {
  // From: https://stackoverflow.com/a/48094758/3164091
  Unmanaged.passUnretained(object).toOpaque()
}

/// Get a pointer's memory address as `Int`.
///
/// This is useful to get `struct` memory address.
///
/// Example:
/// ```swift
/// var foo = FooStrut()
/// memoryAddress(&foo) // 6171903744
/// ```
///
/// - Parameter object: A pointer.
/// - Returns: Memory address.
@inlinable
@inline(__always)
func memoryAddress(_ pointer: UnsafeRawPointer) -> Int {
  Int(bitPattern: pointer)
}

/// Get the pointer's memory address as `String`.
///
/// This is useful to get `struct` memory address.
///
/// Example:
/// ```swift
/// var foo = FooStrut()
/// memoryAddressString(&foo) // "0x16fdfc700"
/// ```
///
/// - Parameter object: A pointer.
/// - Returns: Memory address.
@inlinable
@inline(__always)
func memoryAddressString(_ pointer: UnsafeRawPointer) -> String {
  String(format: "%p", memoryAddress(pointer))
}

/// Get the object's memory address as `String`.
///
/// This is useful to get `struct` memory address.
///
/// Example:
/// ```swift
/// memoryAddressString(object) // "0x16fdfc700"
/// ```
///
/// - Parameter object: An object.
/// - Returns: Memory address.
@inlinable
@inline(__always)
func memoryAddressString(_ object: AnyObject) -> String {
  String(format: "%p", memoryAddress(rawPointer(object)))
}
