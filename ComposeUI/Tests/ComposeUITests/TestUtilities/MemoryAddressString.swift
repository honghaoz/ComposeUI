//
//  MemoryAddressString.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/19/25.
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
